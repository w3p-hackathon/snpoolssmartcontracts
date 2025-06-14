// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SimpleAirdropScheme {
    struct Reward {
      uint256 value;
      bytes32 root;

    }
    mapping (uint256 =>Reward) rewards;
    mapping (bytes32=>bool) nullifiers;

    constructor() {
    }

    function verify(
        bytes32[] memory proof,
        bytes32 commitment,
        bytes32 secret,
        uint256 rewardId
    ) public {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(commitment, secret))));
        Reward memory r = rewards[rewardId];

        require(!nullifiers[leaf],"reward redeemed");
        nullifiers[leaf] = true;
        require(MerkleProof.verify(proof, r.root, leaf), "Invalid proof");
        bool sent = payable(msg.sender).send(r.value);//fix later (4)
        require(sent, "Failed to send ether");
    }

}
