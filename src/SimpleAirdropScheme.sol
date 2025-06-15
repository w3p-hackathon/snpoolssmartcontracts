// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SimpleAirdropScheme is ERC20 {
    struct Reward {
        uint256 value;
        bytes32 root;
    }
    mapping(uint256 => Reward) rewards;
    uint256 rewardsIds;
    mapping(bytes32 => bool) nullifiers;

    constructor() ERC20("SNPool", "SNP") {}

    function verify(
        bytes32[] memory proof,
        bytes32 commitment,
        bytes32 secret,
        uint256 rewardId
    ) public {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(commitment, secret)))
        );
        Reward memory r = rewards[rewardId];

        require(!nullifiers[leaf], "reward redeemed");
        nullifiers[leaf] = true;
        require(MerkleProof.verify(proof, r.root, leaf), "Invalid proof");
        //bool sent = payable(msg.sender).send(r.value); //fix later (4)
        transferFrom(address(this), msg.sender, r.value);
        //require(sent, "Failed to send ether");
    }

    function mint(address recipient, uint256 amt) public {
        _mint(recipient, amt);
    }

    function createReward(uint256 value, bytes32 root) public {
        uint256 currentId = rewardsIds;
        Reward memory reward = Reward({value: value, root: root});
        rewards[currentId] = reward;
        rewardsIds++;
    }

    function stake(uint256 amount) external {
        //approve beforehand
        transferFrom(msg.sender, address(this), amount);
    }
}
