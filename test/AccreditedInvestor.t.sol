// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import "../src/token/Token.sol";
import "../src/token/IToken.sol";
import "../src/compliance/modular/ModularCompliance.sol";
import "../src/compliance/modular/modules/AccreditedInvestor.sol";
import "../lib/st-identity-registry/src/AttributeRegistry.sol";
import "../lib/st-identity-registry/src/libraries/Attributes.sol";

contract AccreditedInvestorTest is Test {
    // Core contracts
    Token public token;
    ModularCompliance public compliance;
    AccreditedInvestor public accreditedModule;
    AttributeRegistry public attributeRegistry;
    
    // Test addresses
    address public deployer = address(0x1);
    address public issuer = address(0x2);
    address public accreditedInvestor1 = address(0x3);
    address public accreditedInvestor2 = address(0x4);
    address public nonAccreditedInvestor = address(0x5);
    address public verifier = address(0x6);
    
    // Setup for tests
    function setUp() public {
        // Start with deployer context
        vm.startPrank(deployer);
        
        // Deploy AttributeRegistry
        attributeRegistry = new AttributeRegistry(verifier);
        
        // Deploy Compliance
        compliance = new ModularCompliance();
        compliance.init();
        
        // Deploy AccreditedInvestor module
        accreditedModule = new AccreditedInvestor();
        accreditedModule.initialize();
        accreditedModule.setAttributeRegistry(address(attributeRegistry));
        
        // Deploy Token
        token = new Token();
        token.init(
            address(attributeRegistry),
            address(compliance),
            "Test Security Token",
            "TST",
            18,
            address(0) // No onchainID needed
        );
        
        // Make sure deployer is an agent
        token.addAgent(deployer);
        
        // Add compliance module
        compliance.bindToken(address(token));
        compliance.addModule(address(accreditedModule));
        
        // Initialize module with compliance
        bytes memory initializeCall = abi.encodeWithSignature("initializeModule(address)", address(compliance));
        compliance.callModuleFunction(initializeCall, address(accreditedModule));
        
        // Set up the token
        token.unpause();
        token.addAgent(issuer);
        
        // Transfer ownership to issuer
        token.transferOwnership(issuer);
        compliance.transferOwnership(issuer);
        
        vm.stopPrank();
        
        // Set up attributes for accredited investors
        vm.startPrank(verifier);
        
        // Set accredited investor attribute for accredited investors
        attributeRegistry.setAttribute(accreditedInvestor1, Attributes.ACCREDITED_INVESTOR, true);
        attributeRegistry.setAttribute(accreditedInvestor2, Attributes.ACCREDITED_INVESTOR, true);
        
        vm.stopPrank();
    }
    
    function testAccreditedInvestorModule() public {
        // Verify the module is correctly set up
        assertTrue(compliance.isModuleBound(address(accreditedModule)), "Module should be bound");
        assertTrue(address(accreditedModule.attributeRegistry()) == address(attributeRegistry), "Attribute registry should be set");
    }
    
    function testMintToAccreditedInvestor() public {
        // Mint tokens to an accredited investor (should succeed)
        vm.startPrank(issuer);
        
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount, "Accredited investor should receive tokens");
        
        vm.stopPrank();
    }
    
    function testMintToNonAccreditedInvestor() public {
        // Attempt to mint to a non-accredited investor (should fail)
        vm.startPrank(issuer);
        
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        
        vm.expectRevert("Recipient is not an accredited investor.");
        token.mint(nonAccreditedInvestor, mintAmount);
        
        assertTrue(token.balanceOf(nonAccreditedInvestor) == 0, "Non-accredited investor should not receive tokens");
        
        vm.stopPrank();
    }
    
    function testTransferToAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Now transfer tokens from one accredited investor to another (should succeed)
        vm.startPrank(accreditedInvestor1);
        uint256 transferAmount = 400 * 10**18; // 400 tokens
        
        token.transfer(accreditedInvestor2, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount - transferAmount, "Sender balance should be reduced");
        assertTrue(token.balanceOf(accreditedInvestor2) == transferAmount, "Receiver should get tokens");
        
        vm.stopPrank();
    }
    
    function testTransferToNonAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Now attempt to transfer tokens to a non-accredited investor (should fail)
        vm.startPrank(accreditedInvestor1);
        uint256 transferAmount = 400 * 10**18; // 400 tokens
        
        vm.expectRevert("Transfer not possible");
        token.transfer(nonAccreditedInvestor, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount, "Sender balance should remain unchanged");
        assertTrue(token.balanceOf(nonAccreditedInvestor) == 0, "Non-accredited investor should not receive tokens");
        
        vm.stopPrank();
    }
    
    function testTransferFromToAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Approve for transferFrom
        vm.startPrank(accreditedInvestor1);
        token.approve(issuer, mintAmount);
        vm.stopPrank();
        
        // Now test transferFrom to an accredited investor (should succeed)
        vm.startPrank(issuer);
        uint256 transferAmount = 300 * 10**18; // 300 tokens
        
        token.transferFrom(accreditedInvestor1, accreditedInvestor2, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount - transferAmount, "Sender balance should be reduced");
        assertTrue(token.balanceOf(accreditedInvestor2) == transferAmount, "Receiver should get tokens");
        
        vm.stopPrank();
    }
    
    function testTransferFromToNonAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Approve for transferFrom
        vm.startPrank(accreditedInvestor1);
        token.approve(issuer, mintAmount);
        vm.stopPrank();
        
        // Now attempt transferFrom to a non-accredited investor (should fail)
        vm.startPrank(issuer);
        uint256 transferAmount = 300 * 10**18; // 300 tokens
        
        vm.expectRevert("Transfer not possible");
        token.transferFrom(accreditedInvestor1, nonAccreditedInvestor, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount, "Sender balance should remain unchanged");
        assertTrue(token.balanceOf(nonAccreditedInvestor) == 0, "Non-accredited investor should not receive tokens");
        
        vm.stopPrank();
    }
    
    function testForceTransferToAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        
        // Force transfer to another accredited investor (should succeed)
        uint256 transferAmount = 500 * 10**18; // 500 tokens
        
        token.forcedTransfer(accreditedInvestor1, accreditedInvestor2, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount - transferAmount, "Sender balance should be reduced");
        assertTrue(token.balanceOf(accreditedInvestor2) == transferAmount, "Receiver should get tokens");
        
        vm.stopPrank();
    }
    
    function testForceTransferToNonAccreditedInvestor() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        
        // Attempt to force transfer to a non-accredited investor (should fail)
        uint256 transferAmount = 500 * 10**18; // 500 tokens
        
        vm.expectRevert("Transfer not possible");
        token.forcedTransfer(accreditedInvestor1, nonAccreditedInvestor, transferAmount);
        
        assertTrue(token.balanceOf(accreditedInvestor1) == mintAmount, "Sender balance should remain unchanged");
        assertTrue(token.balanceOf(nonAccreditedInvestor) == 0, "Non-accredited investor should not receive tokens");
        
        vm.stopPrank();
    }
    
    function testRemovingAccreditation() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Transfer should work between accredited investors
        vm.startPrank(accreditedInvestor1);
        token.transfer(accreditedInvestor2, 100 * 10**18);
        vm.stopPrank();
        
        // Now remove accreditation from investor2
        vm.startPrank(verifier);
        attributeRegistry.revokeAttribute(accreditedInvestor2, Attributes.ACCREDITED_INVESTOR);
        vm.stopPrank();
        
        // Transfer to now non-accredited investor should fail
        vm.startPrank(accreditedInvestor1);
        vm.expectRevert("Transfer not possible");
        token.transfer(accreditedInvestor2, 100 * 10**18);
        vm.stopPrank();
    }
    
    function testAddingAccreditation() public {
        // First mint tokens to an accredited investor
        vm.startPrank(issuer);
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        token.mint(accreditedInvestor1, mintAmount);
        vm.stopPrank();
        
        // Transfer to non-accredited investor should fail
        vm.startPrank(accreditedInvestor1);
        vm.expectRevert("Transfer not possible");
        token.transfer(nonAccreditedInvestor, 100 * 10**18);
        vm.stopPrank();
        
        // Now give accreditation to the non-accredited investor
        vm.startPrank(verifier);
        attributeRegistry.setAttribute(nonAccreditedInvestor, Attributes.ACCREDITED_INVESTOR, true);
        vm.stopPrank();
        
        // Transfer should now succeed
        vm.startPrank(accreditedInvestor1);
        token.transfer(nonAccreditedInvestor, 100 * 10**18);
        assertTrue(token.balanceOf(nonAccreditedInvestor) == 100 * 10**18, "Newly accredited investor should receive tokens");
        vm.stopPrank();
    }
}