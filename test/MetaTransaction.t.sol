// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleTokenWithPermit
 * @dev A simple ERC20 token with EIP-2612 permit functionality for testing meta-transactions
 */
contract SimpleTokenWithPermit is ERC20 {
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) public nonces;
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "SimpleToken: permit expired");
        
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline
            )
        );
        
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner, "SimpleToken: invalid signature");
        
        _approve(owner, spender, value);
    }
}

contract MetaTransactionTest is Test {
    // Constants matching the token
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    // Test contracts
    SimpleTokenWithPermit token;
    
    // Test accounts
    address deployer;
    address recipient = 0x9070459bB0cdA8a9dC3C58076a5cF28c41f3Db57;
    address relayer = address(0x4);
    
    // Private key for deployer (for signing) - loaded from environment
    uint256 deployerPrivateKey;

    function setUp() public {
        // Load environment variables
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        // Deploy simple token for testing meta-transactions
        token = new SimpleTokenWithPermit("MetaTest Token", "MTT");
        
        // Mint tokens to deployer
        token.mint(deployer, 1000 ether);
    }
    
    function testPermitAndTransfer() public {
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(deployer);
        
        // Create the permit digest allowing recipient to spend deployer's tokens
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                deployer,
                recipient,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // Sign the digest with deployer's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);
        
        // Verify deployer's balance before
        assertEq(token.balanceOf(deployer), 1000 ether, "Initial deployer balance incorrect");
        assertEq(token.balanceOf(recipient), 0, "Initial recipient balance should be 0");
        assertEq(token.allowance(deployer, recipient), 0, "Initial allowance should be 0");
        
        // Execute permit as relayer (any address can call this)
        vm.prank(relayer);
        token.permit(deployer, recipient, amount, deadline, v, r, s);
        
        // Verify the allowance was set
        assertEq(token.allowance(deployer, recipient), amount, "Allowance not set correctly");
        
        // Now recipient can transfer tokens from deployer
        vm.prank(recipient);
        token.transferFrom(deployer, recipient, amount);
        
        // Verify final balances
        assertEq(token.balanceOf(deployer), 900 ether, "Deployer balance after transfer incorrect");
        assertEq(token.balanceOf(recipient), 100 ether, "Recipient balance after transfer incorrect");
        assertEq(token.allowance(deployer, recipient), 0, "Allowance should be consumed");
    }
    
    function testPermitExpired() public {
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp - 1; // Expired deadline
        uint256 nonce = token.nonces(deployer);
        
        // Create the permit digest
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                deployer,
                recipient,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);
        
        // Try to execute expired permit
        vm.expectRevert("SimpleToken: permit expired");
        token.permit(deployer, recipient, amount, deadline, v, r, s);
    }
    
    function testPermitInvalidSignature() public {
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(deployer);
        
        // Create the permit digest
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                deployer,
                recipient,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // Sign with wrong private key
        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        
        // Try to execute permit with invalid signature
        vm.expectRevert("SimpleToken: invalid signature");
        token.permit(deployer, recipient, amount, deadline, v, r, s);
    }
    
    function testPermitNonceReplay() public {
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(deployer);
        
        // Create the permit digest
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                deployer,
                recipient,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);
        
        // Execute permit
        token.permit(deployer, recipient, amount, deadline, v, r, s);
        
        // Verify nonce was incremented
        assertEq(token.nonces(deployer), nonce + 1, "Nonce should be incremented");
        
        // Try to replay the same permit
        vm.expectRevert("SimpleToken: invalid signature");
        token.permit(deployer, recipient, amount, deadline, v, r, s);
    }
    
    function testCompleteMetaTransactionFlow() public {
        // This test demonstrates a complete meta-transaction flow:
        // 1. Deployer signs a permit off-chain
        // 2. Relayer submits the permit on-chain
        // 3. Recipient executes transferFrom
        
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(deployer);
        
        // Deployer creates and signs the permit off-chain
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                deployer,
                recipient, // Deployer permits recipient to spend their tokens
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);
        
        // Relayer submits the permit on-chain
        vm.prank(relayer);
        token.permit(deployer, recipient, amount, deadline, v, r, s);
        
        // Recipient can now transfer tokens from deployer to themselves
        vm.prank(recipient);
        token.transferFrom(deployer, recipient, amount);
        
        // Verify the transfer succeeded
        assertEq(token.balanceOf(deployer), 900 ether, "Deployer balance incorrect");
        assertEq(token.balanceOf(recipient), 100 ether, "Recipient balance incorrect");
    }
    
    function testDomainSeparatorValues() public {
        // Test that domain separator is constructed correctly
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("MetaTest Token")),
                keccak256(bytes("1")), // version "1" as defined in the token
                block.chainid,
                address(token)
            )
        );
        
        assertEq(token.DOMAIN_SEPARATOR(), expectedDomainSeparator, "Domain separator mismatch");
    }
}