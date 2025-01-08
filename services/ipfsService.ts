import { create, IPFSHTTPClient } from 'ipfs-http-client';
import pinataSDK from '@pinata/sdk';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

class IPFSService {
  private ipfsClient: IPFSHTTPClient;
  private pinataClient: any;

  constructor() {
    // Validate environment variables
    this.validateEnvVars();

    // Connect to IPFS
    this.ipfsClient = create({ 
      host: 'ipfs.infura.io', 
      port: 5001, 
      protocol: 'https',
      headers: {
        authorization: `Basic ${Buffer.from(
          `${process.env.INFURA_IPFS_PROJECT_ID}:${process.env.INFURA_IPFS_PROJECT_SECRET}`
        ).toString('base64')}`
      }
    });

    // Initialize Pinata for pinning
    this.pinataClient = new pinataSDK(
      process.env.PINATA_API_KEY, 
      process.env.PINATA_SECRET_KEY
    );
  }

  // Validate required environment variables
  private validateEnvVars() {
    const requiredVars = [
      'INFURA_IPFS_PROJECT_ID',
      'INFURA_IPFS_PROJECT_SECRET',
      'PINATA_API_KEY',
      'PINATA_SECRET_KEY'
    ];

    requiredVars.forEach(varName => {
      if (!process.env[varName]) {
        throw new Error(`Missing required environment variable: ${varName}`);
      }
    });
  }

  // Upload file to IPFS
  async uploadFile(filePath: string): Promise<string> {
    try {
      // Validate file exists
      if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
      }

      // Read file
      const fileBuffer = fs.readFileSync(filePath);
      const fileName = path.basename(filePath);
      
      // Upload to IPFS
      const added = await this.ipfsClient.add({ 
        path: fileName, 
        content: fileBuffer 
      });
      
      // Pin the file with Pinata
      await this.pinataClient.pinByHash(added.cid.toString());
      
      return added.cid.toString();
    } catch (error) {
      console.error('IPFS Upload Error:', error);
      throw error;
    }
  }

  // Upload JSON metadata to IPFS
  async uploadJSONMetadata(metadata: object): Promise<string> {
    try {
      // Validate metadata
      if (!metadata || Object.keys(metadata).length === 0) {
        throw new Error('Metadata cannot be empty');
      }

      // Convert metadata to buffer
      const buffer = Buffer.from(JSON.stringify(metadata));
      
      // Upload to IPFS
      const added = await this.ipfsClient.add({
        path: 'metadata.json',
        content: buffer
      });
      
      // Pin the metadata with Pinata
      await this.pinataClient.pinByHash(added.cid.toString());
      
      return added.cid.toString();
    } catch (error) {
      console.error('IPFS Metadata Upload Error:', error);
      throw error;
    }
  }

  // Retrieve file from IPFS
  async retrieveFile(ipfsHash: string): Promise<Buffer> {
    try {
      const chunks = [];
      for await (const chunk of this.ipfsClient.cat(ipfsHash)) {
        chunks.push(chunk);
      }
      return Buffer.concat(chunks);
    } catch (error) {
      console.error('IPFS File Retrieval Error:', error);
      throw error;
    }
  }

  // Additional utility method to pin existing hash
  async pinFile(ipfsHash: string): Promise<void> {
    try {
      await this.pinataClient.pinByHash(ipfsHash);
    } catch (error) {
      console.error('Pinning Error:', error);
      throw error;
    }
  }
}

export default new IPFSService();