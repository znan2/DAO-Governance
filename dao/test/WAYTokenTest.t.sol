// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// MakerDAO token-tests의 표준 테스트 컨트랙트를 상속합니다.
import "token-tests/TokenTests.sol";
import "../src/WAYToken.sol";

contract WAYTokenTest is TokenTests {
    function setUp() public {
        // WAYToken을 배포하고 테스트 변수들을 설정합니다.
        _token_ = address(new WAYToken());
        _contractName_ = "WAYToken";
        _tokenName_ = "WAY Token";
        _symbol_ = "WAY";
        _version_ = "1"; // 선택 사항
        _decimals_ = 18; // 선택 사항, 기본값 18로 가정
    }
}
