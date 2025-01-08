// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19 ;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CertificateRegistry is Ownable {
    constructor() Ownable(msg.sender) {}
    struct Certificate {
        address recipient;
        uint256 issuedAt;
        string metadataHash;
        bool isValid;
    }

    mapping(bytes32 => Certificate) public certificates;
    mapping(address => bytes32[]) public recipientCertificates;

    event CertificateIssued(
        bytes32 indexed certificateId, 
        address indexed recipient, 
        string metadataHash
    );
    event CertificateRevoked(
        bytes32 indexed certificateId
    );

    function issueCertificate(
        address _recipient, 
        string memory _metadataHash
    ) external onlyOwner returns (bytes32) {
        require(_recipient != address(0), "Invalid recipient");
        require(bytes(_metadataHash).length > 0, "Invalid metadata hash");

        bytes32 certificateId = keccak256(
            abi.encodePacked(_recipient, _metadataHash, block.timestamp)
        );

        certificates[certificateId] = Certificate({
            recipient: _recipient,
            issuedAt: block.timestamp,
            metadataHash: _metadataHash,
            isValid: true
        });

        recipientCertificates[_recipient].push(certificateId);

        emit CertificateIssued(certificateId, _recipient, _metadataHash);
        return certificateId;
    }

    function verifyCertificate(
        bytes32 _certificateId
    ) external view returns (bool, address, uint256, string memory) {
        Certificate memory cert = certificates[_certificateId];
        return (
            cert.isValid, 
            cert.recipient, 
            cert.issuedAt, 
            cert.metadataHash
        );
    }

    function revokeCertificate(
        bytes32 _certificateId
    ) external onlyOwner {
        require(
            certificates[_certificateId].isValid, 
            "Certificate already revoked"
        );
        
        certificates[_certificateId].isValid = false;
        emit CertificateRevoked(_certificateId);
    }
}