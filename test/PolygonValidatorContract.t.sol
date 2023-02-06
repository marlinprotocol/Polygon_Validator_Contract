// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PolygonValidatorContract.sol";

contract PolygonValidatorContractTest is Test {
    address constant PARTY_A = 0x436c9FfE3aCaa06aa6bc9064B52b5796208B043F; // holds NFT on mainnet
    address constant PARTY_B = 0x91c35C57D46E2f94Dae175208A42F1B28249863d;
    address constant RANDOM_ADDRESS1 = 0xD7C358434D82046616E9A15045F6e36583eA6069;
    address constant RANDOM_ADDRESS2 = 0x848F11E9c468be9EF6bF5F1Daa742e6ADF25D7A7;

    address constant RANDOM_NFT = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant RANDOM_NFT_OWNER = 0x0459B3FBf7c1840ee03a63ca4AA95De48322322e;
    address constant OTHER_VALIDATOR_ADDRESS = 0x0e40A29974CEefEf971ef3C19F21B7b5858A3d0C;
    uint256 constant OTHER_VALIDATOR_ID = 111;
    bytes constant RANDOM_PUBKEY = hex'e68acfc0253a10620dff706b0a1b1f1f5833ea3beb3bde2250d5f271f3563606672ebc45e0b7ea2e816ecb70ca03137b1c9476eec63d4632e990020b7b6fba39';

    bytes32 ROLE_A;
    bytes32 ROLE_B;

    PolygonValidatorContract validatorContract;

    function setUp() public {
        require(block.chainid == 1, "Invalid network");
        validatorContract = new PolygonValidatorContract(PARTY_B);

        vm.label(PARTY_A, "PARTY_A");
        vm.label(PARTY_B, "PARTY_B");
        vm.label(RANDOM_ADDRESS1, "RANDOM_ADDRESS1");
        vm.label(RANDOM_ADDRESS2, "RANDOM_ADDRESS2");

        ROLE_A = validatorContract.ROLE_A();
        ROLE_B = validatorContract.ROLE_B();
    }

    function testAdminRole() public {
        bytes32 DEFAULT_ADMIN_ROLE = validatorContract.DEFAULT_ADMIN_ROLE();
        // No one has default admin role, so no admin for the contracts
        assertEq(validatorContract.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 0);
    }

    function testpartyBRolePreveliges() public {
        vm.startPrank(PARTY_B);
        // someone with ROLE_B can grant same role to a random address
        validatorContract.grantRole(ROLE_B, RANDOM_ADDRESS1);
        // PARTY_B can revoke it's own ROLE_B role
        validatorContract.revokeRole(ROLE_B, PARTY_B);
        vm.stopPrank();

        vm.startPrank(RANDOM_ADDRESS1);
        // an address whole role was revoked can be added again
        validatorContract.grantRole(ROLE_B, PARTY_B);
        // if necessary removed again as well
        validatorContract.revokeRole(ROLE_B, PARTY_B);
        vm.stopPrank();
    }

    function testDepositSpecifiedNFT() public {
        (address nftContract, uint256 nftId) = _depositNFT();
        console.log(validatorContract.getRoleMember(ROLE_A, 0));
        assertEq(IERC721(nftContract).ownerOf(nftId), address(validatorContract));
        assertEq(validatorContract.getRoleMember(ROLE_A, 0), PARTY_A);
        assertEq(validatorContract.getRoleMemberCount(ROLE_B), 1);
    }

    function testPartyARolePreveliges() public {
        _depositNFT();
        vm.startPrank(PARTY_A);
        // someone with ROLE_A can grant same role to a random address
        validatorContract.grantRole(ROLE_A, RANDOM_ADDRESS1);
        // PARTY_B can revoke it's own ROLE_A role
        validatorContract.revokeRole(ROLE_A, PARTY_B);
        vm.stopPrank();

        vm.startPrank(RANDOM_ADDRESS1);
        // an address whole role was revoked can be added again
        validatorContract.grantRole(ROLE_A, PARTY_A);
        // if necessary removed again as well
        validatorContract.revokeRole(ROLE_A, PARTY_A);
        vm.stopPrank();
    }

    function testPartyBRole() public {
        // anyone with ROLE_B can add/remove others for ROLE_B
        assertEq(validatorContract.getRoleAdmin(ROLE_B), ROLE_B);
        // PARTY_B specified in constructor has ROLE_B
        assertEq(validatorContract.getRoleMember(ROLE_B, 0), PARTY_B);
        // only PARTY_B should have ROLE_B initially
        assertEq(validatorContract.getRoleMemberCount(ROLE_B), 1);
    }

    function testPartyARole() public {
        // anyone with ROLE_A can add/remove others for ROLE_A
        assertEq(validatorContract.getRoleAdmin(ROLE_A), ROLE_A);
        // noone should have ROLE_A initially
        assertEq(validatorContract.getRoleMemberCount(ROLE_A), 0);
    }

    function testPartyACannotRenounceIfAlone() public {
        _depositNFT();
        vm.startPrank(PARTY_A);
        vm.expectRevert("noone else with revoked role");
        validatorContract.renounceRole(ROLE_A, PARTY_A);
        vm.expectRevert("noone else with revoked role");
        validatorContract.revokeRole(ROLE_A, PARTY_A);
        vm.stopPrank();
    }

    function testPartyBCannotRenounceIfAlone() public {
        vm.startPrank(PARTY_B);
        vm.expectRevert("noone else with revoked role");
        validatorContract.renounceRole(ROLE_B, PARTY_B);
        vm.expectRevert("noone else with revoked role");
        validatorContract.revokeRole(ROLE_B, PARTY_B);
        vm.stopPrank();
    }

    function testPartyACanRenounceIfNotAlone1() public {
        _depositNFT();
        vm.startPrank(PARTY_A);
        validatorContract.grantRole(ROLE_A, RANDOM_ADDRESS1);
        validatorContract.renounceRole(ROLE_A, PARTY_A);
        vm.stopPrank();
    }

    function testPartyACanRenounceIfNotAlone2() public {
        _depositNFT();
        vm.startPrank(PARTY_A);
        validatorContract.grantRole(ROLE_A, RANDOM_ADDRESS1);
        validatorContract.revokeRole(ROLE_A, PARTY_A);
        vm.stopPrank();
    }

    function testPartyBCanRenounceIfNotAlone1() public {
        vm.startPrank(PARTY_B);
        validatorContract.grantRole(ROLE_B, RANDOM_ADDRESS1);
        validatorContract.renounceRole(ROLE_B, PARTY_B);
        vm.stopPrank();
    }

    function testPartyBCanRenounceIfNotAlone2() public {
        vm.startPrank(PARTY_B);
        validatorContract.grantRole(ROLE_B, RANDOM_ADDRESS1);
        validatorContract.revokeRole(ROLE_B, PARTY_B);
        vm.stopPrank();
    }

    function testPartyACannnotGrantPartyBRole() public {
        _depositNFT();
        vm.expectRevert("AccessControl: account 0x436c9ffe3acaa06aa6bc9064b52b5796208b043f is missing role 0x32bb8ab2ea72d734393215719f381c927f1f09c5b13ffa9843cd20a72abb21e5");
        vm.prank(PARTY_A);
        validatorContract.grantRole(ROLE_B, RANDOM_ADDRESS1);
    }

    function testPartyBCannnotGrantPartyARole() public {
        vm.expectRevert("AccessControl: account 0x91c35c57d46e2f94dae175208a42f1b28249863d is missing role 0xd43a3f08296bc32a5e577c40261fb506f8b88fac684c6424c0caa39b915b8a87");
        vm.prank(PARTY_B);
        validatorContract.grantRole(ROLE_A, RANDOM_ADDRESS1);
        _depositNFT();
        vm.expectRevert("AccessControl: account 0x91c35c57d46e2f94dae175208a42f1b28249863d is missing role 0xd43a3f08296bc32a5e577c40261fb506f8b88fac684c6424c0caa39b915b8a87");
        vm.prank(PARTY_B);
        validatorContract.grantRole(ROLE_A, RANDOM_ADDRESS1);
    }

    function testCannotDepositRandomNFT() public {
        uint256 nftId = validatorContract.VALIDATOR_NFT_ID();
        vm.expectRevert("Unknown NFT");
        vm.prank(RANDOM_NFT_OWNER);
        IERC721(RANDOM_NFT).safeTransferFrom(RANDOM_NFT_OWNER, address(validatorContract), nftId);
    }

    function testCannotDepositDiffValidatorNFT() public {
        address nftContract = validatorContract.POLYGON_VALIDATOR_NFT_CONTRACT();
        vm.expectRevert("Unexpected NFT Id");
        vm.prank(OTHER_VALIDATOR_ADDRESS);
        IERC721(nftContract).safeTransferFrom(OTHER_VALIDATOR_ADDRESS, address(validatorContract), OTHER_VALIDATOR_ID);
    }

    function testAdminNFTWithdrawal() public {
        (address nftContract, uint256 nftId) = _depositNFT();
        vm.startPrank(PARTY_A);
        validatorContract.withdrawValidatorNFT(RANDOM_ADDRESS1);
        assertEq(IERC721(nftContract).ownerOf(nftId), RANDOM_ADDRESS1);
    }

    function testPartyBCannotWithdrawNFT() public {
        _depositNFT();
        vm.expectRevert("AccessControl: account 0x91c35c57d46e2f94dae175208a42f1b28249863d is missing role 0xd43a3f08296bc32a5e577c40261fb506f8b88fac684c6424c0caa39b915b8a87");
        vm.startPrank(PARTY_B);
        validatorContract.withdrawValidatorNFT(PARTY_A);
    }

    function testRandomAddressCannotWithdrawNFT() public {
        _depositNFT();
        vm.expectRevert("AccessControl: account 0xd7c358434d82046616e9a15045f6e36583ea6069 is missing role 0xd43a3f08296bc32a5e577c40261fb506f8b88fac684c6424c0caa39b915b8a87");
        vm.startPrank(RANDOM_ADDRESS1);
        validatorContract.withdrawValidatorNFT(PARTY_A);
    }

    function testCannotWithdrawNFTToContract() public {
        _depositNFT();
        vm.expectRevert("Receiver is a contract");
        vm.startPrank(PARTY_A);
        validatorContract.withdrawValidatorNFT(address(validatorContract));
    }

    function testCommissionUpdate() public {
        _depositNFT();
        vm.startPrank(PARTY_B);
        validatorContract.updateCommissionRate(40);
    }

    function testSignerUpdate() public {
        _depositNFT();
        vm.startPrank(PARTY_B);
        validatorContract.updateSigner(RANDOM_PUBKEY);
    }

    function testWithdrawRewards() public {
        _depositNFT();
        vm.startPrank(PARTY_B);
        validatorContract.withdrawRewards();
    }

    function _depositNFT() internal returns(address, uint256) {
        vm.startPrank(PARTY_A, PARTY_A);
        address nftContract = validatorContract.POLYGON_VALIDATOR_NFT_CONTRACT();
        uint256 nftId = validatorContract.VALIDATOR_NFT_ID();
        IERC721(nftContract).safeTransferFrom(PARTY_A, address(validatorContract), nftId);
        vm.stopPrank();
        return (nftContract, nftId);
    }
}