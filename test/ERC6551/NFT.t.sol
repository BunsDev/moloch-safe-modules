// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Account } from "src/CookieJarERC6551/ERC6551Module.sol";
import { ERC20Mintable } from "test/utils/ERC20Mintable.sol";
import { IPoster } from "@daohaus/baal-contracts/contracts/interfaces/IPoster.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { AccountRegistry } from "src/CookieJarERC6551/ERC6551Registry.sol";
import { IRegistry } from "src/interfaces/IERC6551Registry.sol";
import { Account } from "src/CookieJarERC6551/ERC6551Module.sol";
import { MinimalReceiver } from "src/lib/MinimalReceiver.sol";
import { MinimalProxyStore } from "src/lib/MinimalProxyStore.sol";

import { CookieNFT } from "src/CookieJarERC6551/CookieNFT.sol";
import { CookieJar6551 } from "src/CookieJarERC6551/CookieJar6551.sol";
import { CookieJar6551Factory } from "src/CookieJarERC6551/CookieJar6551Summoner.sol";
import { ListCookieJar6551 } from "src/CookieJarERC6551/ListCookieJar6551.sol";

import "forge-std/console.sol";


contract AccountRegistryTest is PRBTest {
    Account public implementation;
    AccountRegistry public accountRegistry;

    CookieJar6551 public cookieJarImp;
    CookieJar6551Factory public cookieJarFactory;
    ListCookieJar6551 public listCookieJarImp;
    CookieNFT public tokenCollection;

    event AccountCreated(address account, address indexed tokenContract, uint256 indexed tokenId);

    function setUp() public {
        implementation = new Account();
        accountRegistry = new AccountRegistry(address(implementation));

        cookieJarFactory = new CookieJar6551Factory();
        listCookieJarImp = new ListCookieJar6551();

        tokenCollection = new CookieNFT(
            address(accountRegistry),
            address(implementation),
            address(cookieJarFactory),
            address(listCookieJarImp)
        );

        vm.mockCall(0x000000000000cd17345801aa8147b8D3950260FF, abi.encodeWithSelector(IPoster.post.selector), "");
    }

    function testCookieMint() 
    public 
    returns (address account, address cookieJar, uint256 tokenId) {
        address user1 = vm.addr(1);
        uint256 cookieAmount = 1e16;
        uint256 periodLength = 3600;
        address cookieToken = address(cookieJarImp);
        address[] memory allowList = new address[](0);

        (account, cookieJar, tokenId) =
            tokenCollection.cookieMint(user1, periodLength, cookieAmount, cookieToken, allowList);

  
        (bool sent, ) = payable(account).call{value: 1 ether}("");
        require(sent, "Failed to send Ether?");

        assertEq(tokenCollection.balanceOf(user1), 1);


    }

    function testCookieAddAccountToAllowListAsOwner() public {
        (address account, address cookieJar,) = testCookieMint();
        Account accountContract = Account(payable(account));
        ListCookieJar6551 listCookieJarContract = ListCookieJar6551(cookieJar);
        
        vm.prank(vm.addr(1));
        accountContract.executeCall(cookieJar, 0, abi.encodeWithSelector(listCookieJarContract.setAllowList.selector, vm.addr(2), true));
        
        assertEq(listCookieJarContract.allowList(vm.addr(2)), true);

    }

    function testCookieRemoveAccountToAllowListAsOwner() public {
        (address account, address cookieJar,) = testCookieMint();
        Account accountContract = Account(payable(account));
        ListCookieJar6551 listCookieJarContract = ListCookieJar6551(cookieJar);
        
        vm.prank(vm.addr(1));
        accountContract.executeCall(cookieJar, 0, abi.encodeWithSelector(listCookieJarContract.setAllowList.selector, vm.addr(2), true));
        vm.prank(vm.addr(1));
        accountContract.executeCall(cookieJar, 0, abi.encodeWithSelector(listCookieJarContract.setAllowList.selector, vm.addr(2), false));
        assertEq(listCookieJarContract.allowList(vm.addr(2)), false);

    }

    function testCookieAllowListWithdraw() public {
        (address account, address cookieJar,) = testCookieMint();
        Account accountContract = Account(payable(account));
        ListCookieJar6551 listCookieJarContract = ListCookieJar6551(cookieJar);

        vm.prank(vm.addr(1));
        accountContract.executeCall(cookieJar, 0, abi.encodeWithSelector(listCookieJarContract.setAllowList.selector, vm.addr(2), true));
        assertEq(listCookieJarContract.allowList(vm.addr(2)), true);

        vm.prank(vm.addr(2));
        ListCookieJar6551(cookieJar).reachInJar(vm.addr(2), "test");
        console.logUint(account.balance);
        // new balance should be 1 eth minus cookie amount
        assertEq(account.balance, 1e18-1e16);
    }

    function testCookieNftTransfer() public {
        (address account, address cookieJar, uint256 tokenId) = testCookieMint();
        vm.prank(vm.addr(1));
        tokenCollection.transferFrom(vm.addr(1), vm.addr(2), tokenId);
        assertEq(tokenCollection.balanceOf(vm.addr(2)), 1);
        assertEq(tokenCollection.balanceOf(vm.addr(1)), 0);

        Account accountContract = Account(payable(account));
        ListCookieJar6551 listCookieJarContract = ListCookieJar6551(cookieJar);
        
        vm.prank(vm.addr(1));
        vm.expectRevert(Account.NotAuthorized.selector);
        accountContract.executeCall(cookieJar, 0, abi.encodeWithSelector(listCookieJarContract.setAllowList.selector, vm.addr(2), true));


    }
}
