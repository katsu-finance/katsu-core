// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IPyth} from '../dependencies/pyth/IPyth.sol';
import {PythStructs} from '../dependencies/pyth/PythStructs.sol';
import {AccessControl} from '../dependencies/openzeppelin/contracts/AccessControl.sol';
import {Errors} from '../protocol/libraries/helpers/Errors.sol';

contract FallbackOracle is AccessControl {
  IPyth public immutable pyth;
  mapping(address => bytes32) public priceIds;
  mapping(address => bool) public isSupporttedAsset;

  constructor(IPyth _pyth, address[] memory _assets, bytes32[] memory _priceIds) {
    pyth = _pyth;
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setPriceId(_assets, _priceIds);
  }

  modifier checkSupporttedAsset(address _asset) {
    require(isSupporttedAsset[_asset], Errors.ASSET_NOT_SUPPORTED);
    _;
  }

  function setPriceId(
    address[] memory _assets,
    bytes32[] memory _priceIds
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPriceId(_assets, _priceIds);
  }

  function _setPriceId(address[] memory _assets, bytes32[] memory _priceIds) internal {
    require(_assets.length == _priceIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    for (uint i = 0; i < _assets.length; i++) {
      priceIds[_assets[i]] = _priceIds[i];
      isSupporttedAsset[_assets[i]] = true;
    }
  }

  function getPriceId(address _asset) public view returns (bytes32 priceId) {
    priceId = priceIds[_asset];
  }

  function getAssetPrice(
    address _asset
  ) public view checkSupporttedAsset(_asset) returns (uint256 price) {
    bytes32 priceId = priceIds[_asset];
    if (priceId != bytes32(0)) {
      return _getAssetPriceByPyth(priceId);
    } else {
      // other price oracle
      return 0;
    }
  }

  function _getAssetPriceByPyth(bytes32 _priceId) internal view returns (uint256 price) {
    PythStructs.Price memory priceInfo = pyth.getPriceNoOlderThan(_priceId, 60);
    if (priceInfo.price >= 0) {
      return uint256(uint64(priceInfo.price));
    } else {
      revert('Price not available');
    }
  }

  function getDecimals(
    address _asset
  ) public view checkSupporttedAsset(_asset) returns (uint8 decimals) {
    bytes32 priceId = priceIds[_asset];
    if (priceId != bytes32(0)) {
      PythStructs.Price memory priceInfo = pyth.getPriceNoOlderThan(priceId, 60);
      decimals = uint8(uint32(-1 * priceInfo.expo));
    } else {
      // other price oracle
      decimals = 18;
    }
  }

  function getAssetPriceAndDecimals(
    address _asset
  ) external view checkSupporttedAsset(_asset) returns (uint256 price, uint8 decimals) {
    price = getAssetPrice(_asset);
    decimals = getDecimals(_asset);
  }
}
