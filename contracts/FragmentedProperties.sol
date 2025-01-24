// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FragmentedNFT is ERC1155, Ownable {
    // Mapping to track the total supply of each token ID
    mapping(uint256 => uint256) public totalSupply;

    // Mapping to store individual URIs for each token ID
    mapping(uint256 => string) private _tokenURIs;

    // Event for minting new tokens
    event FragmentedNFTMinted(uint256 indexed tokenId, uint256 fractions, address indexed minter);

    constructor() ERC1155("") {} // Base URI can be left empty since we'll use unique URIs

    /**
     * @dev Mint a new NFT with a specified number of fractions and set a custom URI.
     * Only the owner can mint.
     * @param tokenId The unique ID for the NFT.
     * @param fractions The number of fragments for the NFT.
     * @param tokenURI The metadata URI for the token.
     */
    function mintFragmentedNFT(uint256 tokenId, uint256 fractions, string memory tokenURI) external onlyOwner {
        require(totalSupply[tokenId] == 0, "Token ID already exists"); // Ensure unique token IDs
        require(fractions > 0, "Fractions must be greater than zero");
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");

        _mint(msg.sender, tokenId, fractions, "");
        totalSupply[tokenId] = fractions;
        _setTokenURI(tokenId, tokenURI);

        emit FragmentedNFTMinted(tokenId, fractions, msg.sender);
    }

    /**
     * @dev Internal function to set a custom URI for a given token ID.
     * @param tokenId The ID of the token.
     * @param tokenURI The URI to associate with the token.
     */
    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(tokenURI, tokenId); // Emit the URI event as per ERC-1155
    }

    /**
     * @dev Get the metadata URI for a given token ID.
     * @param tokenId The ID of the token.
     * @return The URI for the token.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(bytes(_tokenURIs[tokenId]).length > 0, "URI not set for this token ID");
        return _tokenURIs[tokenId];
    }
}
