// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TransparentUpgradeableProxy
 * @dev EIP-1967에 따라 구현(implementation)과 관리(admin) 주소를 저장하는
 * 프록시 컨트랙트입니다. 관리자는 upgradeTo()를 통해 구현 주소를 변경할 수 있습니다.
 */
contract DaoProxy {
    // EIP-1967: keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // EIP-1967: keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e0195ec3d0a7c12f5a10732b6f8c8f3f3;

    /**
     * @dev Constructor
     * @param _logic 초기 구현(업그레이드할 DaoGovernance 컨트랙트 주소)
     * @param admin_ 관리자의 주소
     * @param _data 초기화 데이터 (예: DaoGovernance 초기화 호출 데이터, 필요 없으면 빈 값)
     */
    constructor(address _logic, address admin_, bytes memory _data) {
        // 관리자 주소 설정
        assembly {
            sstore(ADMIN_SLOT, admin_)
        }
        // 구현 주소 설정
        _setImplementation(_logic);
        // 초기화 데이터가 있으면 delegatecall로 초기화 함수 호출
        if(_data.length > 0) {
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    /**
     * @dev 내부 함수: 구현 주소 설정
     */
    function _setImplementation(address _logic) internal {
        require(_logic.code.length > 0, "Implementation is not a contract");
        assembly {
            sstore(IMPLEMENTATION_SLOT, _logic)
        }
    }

    /**
     * @notice 관리자 전용: 구현 주소 업그레이드
     * @param newImplementation 새 구현 컨트랙트 주소
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _setImplementation(newImplementation);
    }

    /**
     * @notice 현재 관리자 주소를 반환
     */
    function admin() external view returns (address adm) {
        assembly {
            adm := sload(ADMIN_SLOT)
        }
    }

    /**
     * @notice 현재 구현 주소를 반환
     */
    function implementation() external view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Modifier: 관리자이면 함수 실행, 아니면 fallback으로 위임 호출
     */
    modifier ifAdmin() {
        if(msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    function _admin() internal view returns (address adm) {
        assembly {
            adm := sload(ADMIN_SLOT)
        }
    }

    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }

    /**
     * @dev 내부 함수: 현재 구현 주소로 delegatecall을 수행
     */
    function _fallback() internal {
        _delegate(_implementation());
    }

    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    function _delegate(address impl) internal {
        assembly {
            // calldata 복사
            calldatacopy(0, 0, calldatasize())
            // delegatecall 실행
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // returndata 복사
            returndatacopy(0, 0, returndatasize())
            // 결과에 따라 반환 또는 revert
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
