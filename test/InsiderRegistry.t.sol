// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/*
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/compliance/modules/InsiderRegistry.sol";
import "../src/compliance/modules/AccreditedInvestor.sol";
import "../src/interfaces/IInsiderRegistry.sol";
import "../src/storage/InsiderStorage.sol";
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol";
import "st-identity-registry/src/AttributeRegistry.sol";
import "st-identity-registry/src/libraries/Attributes.sol";
*/
/**
 * @title InsiderRegistryTest
 * @dev Test contract for InsiderRegistry and its integration with AccreditedInvestor module
 */
/*
contract InsiderRegistryTest is Test {
    // Contracts
    InsiderRegistry public insiderRegistry;
    AccreditedInvestor public accreditedInvestor;
    AttributeRegistry public attributeRegistry;
    
    // Test accounts
    address public deployer = address(this);
    address public admin = address(0x1);
    address public agent = address(0x2);
    address public founder = address(0x3);
    address public executive = address(0x4);
    address public director = address(0x5);
    address public employee = address(0x6);
    address public investor = address(0x7);
    address public nonAccreditedInvestor = address(0x8);
    
    // Events for testing
    event InsiderAdded(address indexed wallet, uint8 insiderType);
    event InsiderRemoved(address indexed wallet);
    event InsiderTypeUpdated(address indexed wallet, uint8 newType);
    event AttributeRegistrySet(address indexed oldRegistry, address indexed newRegistry);
    event InsiderRegistrySet(address indexed oldRegistry, address indexed newRegistry);
    event InsiderExemptionSet(bool exemptionStatus);
    
    function setUp() public {
        // Deploy and initialize contracts
        vm.startPrank(deployer);
        
        // Deploy and initialize insider registry
        insiderRegistry = new InsiderRegistry();
        insiderRegistry.initialize();
        
        // Deploy attribute registry for accredited investor checks with deployer as verifier
        attributeRegistry = new AttributeRegistry(deployer);
        
        // Deploy and initialize accredited investor module
        accreditedInvestor = new AccreditedInvestor();
        accreditedInvestor.initialize();
        
        // Set up attribute registry
        accreditedInvestor.setAttributeRegistry(address(attributeRegistry));
        
        // Set up insider registry in accredited investor module
        accreditedInvestor.setInsiderRegistry(address(insiderRegistry));
        accreditedInvestor.setInsidersExemptFromAccreditation(true);
        
        // Add agent role to the agent account
        insiderRegistry.addAgent(agent);
        
        // Set accreditation for the investor
        attributeRegistry.setAttribute(investor, Attributes.ACCREDITED_INVESTOR, true);
        
        vm.stopPrank();
    }
    
    //------------------------------------------------------------
    // InsiderRegistry Contract Tests
    //------------------------------------------------------------
    
    /**
     * @dev Test the initialization of the InsiderRegistry
     */
    /*
    function testInitialization() public {
        // Deployer should be an agent
        assertTrue(insiderRegistry.isAgent(deployer));
        
        // Deployer should be an insider with AGENT type
        assertTrue(insiderRegistry.isInsider(deployer));
        assertEq(insiderRegistry.getInsiderType(deployer), uint8(IInsiderRegistry.InsiderType.AGENT));
        
        // Initial insiders list should contain the deployer
        address[] memory insiders = insiderRegistry.getInsiders();
        assertEq(insiders.length, 1);
        assertEq(insiders[0], deployer);
        
        // Initial AGENT type list should contain the deployer
        address[] memory agentInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.AGENT));
        assertEq(agentInsiders.length, 1);
        assertEq(agentInsiders[0], deployer);
    }
    
    /**
     * @dev Test adding insiders through the contract
     */
    /*
    function testAddInsider() public {
        // Test adding insiders as deployer (owner)
        vm.startPrank(deployer);
        
        // Add founder
        vm.expectEmit(true, false, false, true);
        emit InsiderAdded(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Add executive
        vm.expectEmit(true, false, false, true);
        emit InsiderAdded(executive, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        insiderRegistry.addInsider(executive, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        // Add director
        vm.expectEmit(true, false, false, true);
        emit InsiderAdded(director, uint8(IInsiderRegistry.InsiderType.DIRECTOR));
        insiderRegistry.addInsider(director, uint8(IInsiderRegistry.InsiderType.DIRECTOR));
        
        // Add employee
        vm.expectEmit(true, false, false, true);
        emit InsiderAdded(employee, uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        insiderRegistry.addInsider(employee, uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        
        vm.stopPrank();
        
        // Verify insiders were added correctly
        assertTrue(insiderRegistry.isInsider(founder));
        assertEq(insiderRegistry.getInsiderType(founder), uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        assertTrue(insiderRegistry.isInsider(executive));
        assertEq(insiderRegistry.getInsiderType(executive), uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        assertTrue(insiderRegistry.isInsider(director));
        assertEq(insiderRegistry.getInsiderType(director), uint8(IInsiderRegistry.InsiderType.DIRECTOR));
        
        assertTrue(insiderRegistry.isInsider(employee));
        assertEq(insiderRegistry.getInsiderType(employee), uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        
        // Verify overall insiders list
        address[] memory allInsiders = insiderRegistry.getInsiders();
        assertEq(allInsiders.length, 5); // deployer + 4 new insiders
        
        // Verify type-specific lists
        address[] memory founderInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.FOUNDER));
        assertEq(founderInsiders.length, 1);
        assertEq(founderInsiders[0], founder);
        
        address[] memory executiveInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        assertEq(executiveInsiders.length, 1);
        assertEq(executiveInsiders[0], executive);
        
        address[] memory directorInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.DIRECTOR));
        assertEq(directorInsiders.length, 1);
        assertEq(directorInsiders[0], director);
        
        address[] memory employeeInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        assertEq(employeeInsiders.length, 1);
        assertEq(employeeInsiders[0], employee);
    }
    
    /**
     * @dev Test adding insiders through an agent
     */
    /*
    function testAddInsiderByAgent() public {
        vm.startPrank(agent);
        
        // Add founder by agent
        vm.expectEmit(true, false, false, true);
        emit InsiderAdded(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        vm.stopPrank();
        
        // Verify insider was added
        assertTrue(insiderRegistry.isInsider(founder));
        assertEq(insiderRegistry.getInsiderType(founder), uint8(IInsiderRegistry.InsiderType.FOUNDER));
    }
    
    /**
     * @dev Test failure cases for adding insiders
     */
    /*
    function testAddInsiderFailures() public {
        // Add founder for later tests
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Test adding insider with unauthorized account
        vm.startPrank(investor);
        vm.expectRevert("InsiderRegistry: caller is not owner or agent");
        insiderRegistry.addInsider(employee, uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        vm.stopPrank();
        
        // Test adding insider with zero address
        vm.startPrank(deployer);
        vm.expectRevert("InsiderRegistry: invalid address");
        insiderRegistry.addInsider(address(0), uint8(IInsiderRegistry.InsiderType.EMPLOYEE));
        
        // Test adding insider with invalid type (0)
        vm.expectRevert("InsiderRegistry: invalid insider type");
        insiderRegistry.addInsider(employee, 0);
        
        // Test adding insider with invalid type (too high)
        vm.expectRevert("InsiderRegistry: invalid insider type");
        insiderRegistry.addInsider(employee, 10);
        
        // Test adding an already registered insider
        vm.expectRevert("InsiderRegistry: address already registered");
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test removing insiders
     */
    /*
    function testRemoveInsider() public {
        // First add some insiders
        vm.startPrank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        insiderRegistry.addInsider(executive, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        vm.stopPrank();
        
        // Verify initial state
        assertTrue(insiderRegistry.isInsider(founder));
        assertTrue(insiderRegistry.isInsider(executive));
        
        // Remove an insider
        vm.startPrank(deployer);
        vm.expectEmit(true, false, false, false);
        emit InsiderRemoved(founder);
        insiderRegistry.removeInsider(founder);
        vm.stopPrank();
        
        // Verify founder was removed
        assertFalse(insiderRegistry.isInsider(founder));
        assertEq(insiderRegistry.getInsiderType(founder), 0);
        
        // Executive should still be an insider
        assertTrue(insiderRegistry.isInsider(executive));
        
        // Check updated lists
        address[] memory allInsiders = insiderRegistry.getInsiders();
        assertEq(allInsiders.length, 2); // deployer + executive
        
        address[] memory founderInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.FOUNDER));
        assertEq(founderInsiders.length, 0); // founder was removed
    }
    
    /**
     * @dev Test failure cases for removing insiders
     */
    /*
    function testRemoveInsiderFailures() public {
        // First add an insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Test removing with unauthorized account
        vm.startPrank(investor);
        vm.expectRevert("InsiderRegistry: caller is not owner or agent");
        insiderRegistry.removeInsider(founder);
        vm.stopPrank();
        
        // Test removing with zero address
        vm.startPrank(deployer);
        vm.expectRevert("InsiderRegistry: invalid address");
        insiderRegistry.removeInsider(address(0));
        
        // Test removing non-registered address
        vm.expectRevert("InsiderRegistry: address not registered");
        insiderRegistry.removeInsider(employee);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test updating insider types
     */
    /*
    function testUpdateInsiderType() public {
        // First add an insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Verify initial type
        assertEq(insiderRegistry.getInsiderType(founder), uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Update insider type
        vm.startPrank(deployer);
        vm.expectEmit(true, false, false, true);
        emit InsiderTypeUpdated(founder, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        insiderRegistry.updateInsiderType(founder, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        vm.stopPrank();
        
        // Verify type was updated
        assertEq(insiderRegistry.getInsiderType(founder), uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        // Check updated lists
        address[] memory founderInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.FOUNDER));
        assertEq(founderInsiders.length, 0); // no more founders
        
        address[] memory executiveInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        assertEq(executiveInsiders.length, 1);
        assertEq(executiveInsiders[0], founder);
    }
    
    /**
     * @dev Test failure cases for updating insider types
     */
    /*
    function testUpdateInsiderTypeFailures() public {
        // First add an insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Test updating with unauthorized account
        vm.startPrank(investor);
        vm.expectRevert("InsiderRegistry: caller is not owner or agent");
        insiderRegistry.updateInsiderType(founder, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        vm.stopPrank();
        
        // Test updating with zero address
        vm.startPrank(deployer);
        vm.expectRevert("InsiderRegistry: invalid address");
        insiderRegistry.updateInsiderType(address(0), uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        // Test updating non-registered address
        vm.expectRevert("InsiderRegistry: address not registered");
        insiderRegistry.updateInsiderType(employee, uint8(IInsiderRegistry.InsiderType.EXECUTIVE));
        
        // Test updating to invalid type (0)
        vm.expectRevert("InsiderRegistry: invalid insider type");
        insiderRegistry.updateInsiderType(founder, 0);
        
        // Test updating to invalid type (too high)
        vm.expectRevert("InsiderRegistry: invalid insider type");
        insiderRegistry.updateInsiderType(founder, 10);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test updating to the same type (should be a no-op)
     */
    /*
    function testUpdateToSameType() public {
        // First add an insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Initial state
        address[] memory founderInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.FOUNDER));
        assertEq(founderInsiders.length, 1);
        
        // Update to same type
        vm.prank(deployer);
        insiderRegistry.updateInsiderType(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Should be unchanged
        founderInsiders = insiderRegistry.getInsidersByType(uint8(IInsiderRegistry.InsiderType.FOUNDER));
        assertEq(founderInsiders.length, 1);
        assertEq(founderInsiders[0], founder);
    }
    
    //------------------------------------------------------------
    // AccreditedInvestor Module Integration Tests
    //------------------------------------------------------------
    
    /**
     * @dev Test setting insider registry in AccreditedInvestor module
     */
    /*
    function testSetInsiderRegistry() public {
        address newRegistry = address(0x9);
        
        vm.startPrank(deployer);
        
        vm.expectEmit(true, true, false, false);
        emit InsiderRegistrySet(address(insiderRegistry), newRegistry);
        accreditedInvestor.setInsiderRegistry(newRegistry);
        
        vm.stopPrank();
        
        assertEq(address(accreditedInvestor.insiderRegistry()), newRegistry);
    }
    
    /**
     * @dev Test setting insider exemption status
     */
    /*
    function testSetInsidersExemptFromAccreditation() public {
        vm.startPrank(deployer);
        
        // Initially set to true in setup
        assertTrue(accreditedInvestor.insidersExemptFromAccreditation());
        
        // Disable exemption
        vm.expectEmit(false, false, false, true);
        emit InsiderExemptionSet(false);
        accreditedInvestor.setInsidersExemptFromAccreditation(false);
        
        assertFalse(accreditedInvestor.insidersExemptFromAccreditation());
        
        // Re-enable exemption
        vm.expectEmit(false, false, false, true);
        emit InsiderExemptionSet(true);
        accreditedInvestor.setInsidersExemptFromAccreditation(true);
        
        assertTrue(accreditedInvestor.insidersExemptFromAccreditation());
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test isAccreditedInvestor with various scenarios
     */
    /*
    function testIsAccreditedInvestor() public {
        // Add founder insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // Test with accredited investor
        assertTrue(accreditedInvestor.isAccreditedInvestor(investor));
        
        // Test with insider (not accredited but exempt)
        assertTrue(accreditedInvestor.isAccreditedInvestor(founder));
        
        // Test with non-accredited, non-insider
        assertFalse(accreditedInvestor.isAccreditedInvestor(nonAccreditedInvestor));
        
        // Disable insider exemption
        vm.prank(deployer);
        accreditedInvestor.setInsidersExemptFromAccreditation(false);
        
        // Now insider should fail the check
        assertFalse(accreditedInvestor.isAccreditedInvestor(founder));
        
        // Accredited investor should still pass
        assertTrue(accreditedInvestor.isAccreditedInvestor(investor));
    }
    
    /**
     * @dev Test moduleCheck functionality with insider exemptions
     */
    /*
    function testModuleCheckWithInsiders() public {
        // Add founder insider
        vm.prank(deployer);
        insiderRegistry.addInsider(founder, uint8(IInsiderRegistry.InsiderType.FOUNDER));
        
        // From anyone to accredited investor should pass
        assertTrue(accreditedInvestor.moduleCheck(deployer, investor, 100, address(0)));
        
        // From anyone to insider should pass (due to exemption)
        assertTrue(accreditedInvestor.moduleCheck(deployer, founder, 100, address(0)));
        
        // From anyone to non-accredited, non-insider should fail
        assertFalse(accreditedInvestor.moduleCheck(deployer, nonAccreditedInvestor, 100, address(0)));
        
        // Zero transfers should always pass
        assertTrue(accreditedInvestor.moduleCheck(deployer, nonAccreditedInvestor, 0, address(0)));
        
        // Burns should always pass
        assertTrue(accreditedInvestor.moduleCheck(deployer, address(0), 100, address(0)));
        
        // Disable insider exemption
        vm.prank(deployer);
        accreditedInvestor.setInsidersExemptFromAccreditation(false);
        
        // Now transfer to insider should fail
        assertFalse(accreditedInvestor.moduleCheck(deployer, founder, 100, address(0)));
    }
}
*/