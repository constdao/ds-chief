// chief.t.sol - test for chief.sol

// Copyright (C) 2017  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "ds-thing/thing.sol";

import "./chief.sol";
import "./chief-exploits.t.sol";

interface Hevm {
    function roll(uint) external;
}

contract ChiefV2User is DSThing {
    DSChiefV2 chief;

    function setChief(address _chief) public {
        require(chief == DSChiefV2(0x0), "already set");
        chief = DSChiefV2(_chief);
    }

    function doLift(address to_lift) public {
        chief.lift(to_lift);
    }

    function doSetUserRole(address who, uint8 role, bool enabled) public {
        chief.setUserRole(who, role, enabled);
    }

    function doSetRoleCapability(uint8 role, address code, bytes4 sig, bool enabled) public {
        chief.setRoleCapability(role, code, sig, enabled);
    }

    function doSetPublicCapability(address code, bytes4 sig, bool enabled) public {
        chief.setPublicCapability(code, sig, enabled);
    }

    function authedFn() public view auth returns (bool) {
        return true;
    }
}

contract DSChiefV2Test is DSThing, DSTest {
    Hevm hevm;
    uint256 constant electionSize = 3;

    // c prefix: candidate
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);


    DSChiefV2 chief;

    // u prefix: user
    ChiefV2User normalUser;
    ChiefV2User authUser;
    ChiefV2User thirdUser;

    function setUp() public {
        hevm = Hevm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

        normalUser = new ChiefV2User();
        authUser = new ChiefV2User();
        thirdUser = new ChiefV2User();

        DSChiefFabV2 fab = new DSChiefFabV2();
        address[] memory lifters = new address[](1);
        lifters[0] = address(authUser);
        chief = fab.newChief(lifters);

        normalUser.setChief(address(chief));
        authUser.setChief(address(chief));
        thirdUser.setChief(address(chief));

        hevm.roll(1);
        // Block number = 1
    }

    function test_launch_hat() public {
        address zero_address = address(0);
        assertEq(chief.hat(), zero_address);
        assertTrue(chief.isUserRoot(zero_address));
    }


    function test_auth_user_lift() public {
        authUser.doLift(c1);
        assertEq(chief.hat(), c1);
        assertTrue(chief.isUserRoot(c1));
    }

    function testFail_normal_user_lift() public {
        normalUser.doLift(c1);
    }


    function testFail_non_hat_can_not_set_roles() public {
        normalUser.doSetUserRole(address(1), 1, true);
    }

    function test_hat_can_set_roles() public {

        // Update the elected set to reflect the new order.
        authUser.doLift(address(normalUser));

        normalUser.doSetUserRole(address(1), 1, true);
    }

    function testFail_non_hat_can_not_role_capability() public {
        normalUser.doSetRoleCapability(1, address(1), S("authedFn"), true);
    }

    function test_hat_can_set_role_capability() public {
        // Update the elected set to reflect the new order.
        authUser.doLift(address(normalUser));

        normalUser.doSetRoleCapability(1, address(thirdUser), S("authedFn()"), true);
        normalUser.doSetUserRole(address(this), 1, true);

        thirdUser.setAuthority(chief);
        thirdUser.setOwner(address(0));
        thirdUser.authedFn();
    }

    function test_hat_can_set_public_capability() public {
        // Update the elected set to reflect the new order.
        authUser.doLift(address(normalUser));

        normalUser.doSetPublicCapability(address(thirdUser), S("authedFn()"), true);

        thirdUser.setAuthority(chief);
        thirdUser.setOwner(address(0));
        thirdUser.authedFn();
    }

    function test_chief_no_owner() public {
        assertEq(chief.owner(), address(0));
    }
}
