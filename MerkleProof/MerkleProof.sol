// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MerkleProofUpgradeable
/// @notice A library for verifying Merkle Tree proofs and multi-proofs.
library MerkleProofUpgradeable {
    error MerkleProofInvalidMultiproof();

    /**
     * @notice Verifies a Merkle proof for a single leaf.
     * @param proof Array of sibling hashes in the proof.
     * @param root Merkle tree root.
     * @param leaf Leaf node to verify.
     * @return True if the leaf is part of the Merkle tree with the given root.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return _processProof(proof, leaf) == root;
    }

    /**
     * @notice Verifies a Merkle proof (Calldata version) for a single leaf.
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return _processProofCalldata(proof, leaf) == root;
    }

    /**
     * @notice Processes a Merkle proof and returns the computed root hash.
     */
    function _processProof(
        bytes32[] memory proof,
        bytes32 leaf
    ) private pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @notice Processes a Merkle proof (Calldata version).
     */
    function _processProofCalldata(
        bytes32[] calldata proof,
        bytes32 leaf
    ) private pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @notice Verifies a Merkle multi-proof.
     * @param proof Array of sibling hashes in the proof.
     * @param proofFlags Instructions for proof processing.
     * @param root Merkle tree root.
     * @param leaves Array of leaf nodes.
     * @return True if the leaves are part of the Merkle tree with the given root.
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return _processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @notice Verifies a Merkle multi-proof (Calldata version).
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return _processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @notice Processes a Merkle multi-proof and computes the root hash.
     */
    function _processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) private pure returns (bytes32) {
        return _processMultiProofInternal(proof, proofFlags, leaves);
    }

    /**
     * @notice Processes a Merkle multi-proof (Calldata version).
     */
    function _processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) private pure returns (bytes32) {
        return _processMultiProofInternal(proof, proofFlags, leaves);
    }

    /**
     * @notice Shared internal function to process multi-proof logic.
     */
    function _processMultiProofInternal(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) private pure returns (bytes32) {
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafIndex = 0;
        uint256 hashIndex = 0;
        uint256 proofIndex = 0;

        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = (leafIndex < leavesLen) ? leaves[leafIndex++] : hashes[hashIndex++];
            bytes32 b = proofFlags[i]
                ? (leafIndex < leavesLen ? leaves[leafIndex++] : hashes[hashIndex++])
                : proof[proofIndex++];
            hashes[i] = _hashPair(a, b);
        }

        if (proofIndex != proofLen) {
            revert MerkleProofInvalidMultiproof();
        }

        return (totalHashes > 0) ? hashes[totalHashes - 1] : (leavesLen > 0 ? leaves[0] : proof[0]);
    }

    /**
     * @notice Hashes two nodes together in order.
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return (a < b) ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @notice Efficiently hashes two 32-byte values using keccak256.
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
