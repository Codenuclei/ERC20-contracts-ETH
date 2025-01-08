// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
  // Deploy Marketplace Contract
  const MarketplaceFactory = await ethers.getContractFactory("Marketplace");
  const marketplace = await MarketplaceFactory.deploy();
  await marketplace.waitForDeployment();
  console.log("Marketplace deployed to:", await marketplace.getAddress());

  // Deploy Certificate Registry Contract
  const CertificateRegistryFactory = await ethers.getContractFactory("CertificateRegistry");
  const certificateRegistry = await CertificateRegistryFactory.deploy();
  await certificateRegistry.waitForDeployment();
  console.log("CertificateRegistry deployed to:", await certificateRegistry.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });