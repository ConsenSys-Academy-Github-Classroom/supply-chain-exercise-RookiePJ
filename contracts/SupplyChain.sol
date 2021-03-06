// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.9.0;

contract SupplyChain {

  /** Storage */

  address public owner;              // <owner>
  uint public skuCount;             // <skuCount>
  mapping (uint => Item) items;     // <items mapping>
  enum State { ForSale, Sold, Shipped, Received }   // <enum State: ForSale, Sold, Shipped, Received>
  struct Item { string name; uint sku; uint price; State state; address payable seller; address payable buyer; }
                                    // <struct Item: name, sku, price, state, seller, and buyer>


  /** Events */

  event LogForSale(uint sku);          // <LogForSale event: sku arg>
  event LogSold(uint sku);             // <LogSold event: sku arg>
  event LogShipped(uint sku);          // <LogShipped event: sku arg>
  event LogReceived(uint sku);         // <LogReceived event: sku arg>


  /** Modifiers */

  // Create a modifer, `isOwner` that checks if the msg.sender is the owner of the contract
  modifier isOwner(address _owner) {         // <modifier: isOwner
      require (msg.sender == _owner);
      _;
  }

  modifier verifyCaller (address _address) {
      require (msg.sender == _address);
      _;
  }

  modifier paidEnough(uint _price) {
      require(msg.value >= _price);
      _;
  }

  modifier checkValue(uint _sku) {
    //refund them after pay for item (why it is before, _ checks for logic before func)
    _;
    uint _price = items[_sku].price;
    uint amountToRefund = msg.value - _price;
    address payable buyerPayable = items[_sku].buyer;
    (bool sent, ) = buyerPayable.call{value: amountToRefund}("");    // transfering overpaid ether refund back to buyer using fallback
    //buyerPayable.transfer(amountToRefund); // this is transfering ether!  converted to use the call on the buyer address
    //items[_sku].buyer.transfer(amountToRefund);
  }

  // For each of the following modifiers, use what you learned about modifiers
  // to give them functionality. For example, the forSale modifier should
  // require that the item with the given sku has the state ForSale. Note that
  // the uninitialized Item.State is 0, which is also the index of the ForSale
  // value, so checking that Item.State == ForSale is not sufficient to check
  // that an Item is for sale. Hint: What item properties will be non-zero when
  // an Item has been added?
  // Answer; (PJR) sku would be 0 when adding first item, therefore seller address is used

  modifier forSale(uint _sku) {                         // modifier forSale
     State saleState = items[_sku].state;
     address sellerAddress = items[_sku].seller;
     // require state to be equal to for sale and a non zero seller address to confirm item is initialised
     require( (saleState == State.ForSale) && (sellerAddress != address(0)), "[forSale] Not for sale");
     _;
  }

  modifier sold(uint _sku) {                            // modifier sold(uint _sku)
      State soldState = items[_sku].state;
      require(soldState == State.Sold, "[sold] Not sold");
      _;
  }

  modifier shipped(uint _sku) {                        // modifier shipped(uint _sku) 
       State shippedState = items[_sku].state;
       require(shippedState == State.Shipped, "[shipped] Not shipped");
       _;
  }

  modifier received(uint _sku) {                       // modifier received(uint _sku)
      State shippedState = items[_sku].state;
      require(shippedState == State.Received, "[received] Not shipped");
      _;
  }

  modifier isSeller(uint _sku) {                      // pjr added - check that seller (msg.sender) is the seller address stored in the item
      address senderAddress = msg.sender;
      address itemSellerAddress = items[_sku].seller;
      require(senderAddress == itemSellerAddress, "[isSeller] Not seller");
      _;
  }

  modifier isBuyer(uint _sku) {                       // pjr added - check the buyer (msg.sender) is the buyer address stored in the item
      address buyerAddress = msg.sender;
      address itemBuyerAddress = items[_sku].buyer;
      require(buyerAddress == itemBuyerAddress, "[isBuyer] Not buyer");
      _;
  }


  /** Functions */

  constructor() {
      owner = msg.sender;            // 1. Set the owner to the transaction sender
      skuCount = 0;                  // 2. Initialize the sku count to 0. Question, is this necessary?
  }                                  //    Answer - not necessary, but cleaner code if you are not dependant upon compiler defaults.
                                     //           - what if future compiler behaviour is changed?  Inheritance and constructor chaining (always a problem in java!)
                                     //           - lastly, the person maintaining the code may not understand default values.

  // Default action when receiving a payment for the contract but without any call data (ie no function is called).
  // Just revert and return the ether in both instances as we expect ether to be sent to this contract using the correct function call ie: buyItem(uint _sku)
  receive() external payable { revert("contract does not accept ether directly"); }
  fallback() external payable { revert("contract does not accept ether directly"); }

  /** Add an item */
  function addItem(string memory _name, uint _price) public returns (bool) {
      // check for valid parameters - ie not empty strings or negative prices
      bytes memory nameStringTest = bytes(_name);
      require(nameStringTest.length > 0, "Invalid item name");        // no zero length strings
      require(_price > 0, "Price must be a positive value");          // Accept zero price values but not negative
                                                                      // using unisgned integer so also watch for buffer underflow/overflow attachs
      // copy into local variables (maybe a waste of gas, but cleaner code, eaiser to understand).
      address payable itemSellerPayable = payable(msg.sender);
      address payable itemBuyerPayable = payable(address(0));

      Item memory newItem = Item(         // 1. Create a new item
          { name: _name, sku: skuCount, price: _price, state: State.ForSale, seller: itemSellerPayable, buyer: itemBuyerPayable }
      );
      items[skuCount] = newItem;          // 1. put in array
      skuCount++;                         // 2. Increment the skuCount by one - for next item
      emit LogForSale(skuCount);          // 3. Emit the appropriate event
      return (true);                      // 4. return true if no problems and require functions were triggered
  }

    // hint:
    // items[skuCount] = Item({
    //  name: _name, 
    //  sku: skuCount, 
    //  price: _price, 
    //  state: State.ForSale, 
    //  seller: msg.sender, 
    //  buyer: address(0)
    //});
    //
    //skuCount = skuCount + 1;
    // emit LogForSale(skuCount);
    // return true;


  // Implement this buyItem function. 
  // 1. it should be payable in order to receive refunds
  // 2. this should transfer money to the seller, 
  // 3. set the buyer as the person who called this transaction, 
  // 4. set the state to Sold. 
  // 5. this function should use 3 modifiers to check 
  //    - if the item is for sale, 
  //    - if the buyer paid enough, 
  //    - check the value after the function is called to make 
  //      sure the buyer is refunded any excess ether sent. 
  // 6. call the event associated with this function!

  /** Buy an item */
  function buyItem(uint _sku) payable public 
    forSale(_sku) paidEnough(items[_sku].price) checkValue(_sku) {

       address payable buyer = payable(msg.sender);
       address payable seller = items[_sku].seller;
       uint itemPrice = items[_sku].price;

       items[_sku].buyer = buyer;
       items[_sku].state = State.Sold;
       require(buyer != address(0x00) );   // require that the buyer has an address and not a zero blank addresses
       require(seller != address(0x00) );   // require that the seller has an address and not a zero blank addresses

       emit LogSold(_sku);

       //transfer money last, to prevent a reentry attach
       (bool sent, ) = seller.call{value: itemPrice}("");
       require (sent == true, "[buyItem] Problem buying item when trying to send ether to seller");
       // we now run the code in checkValue(_sku) and any remaining overpaided ether is returned to the buyer

       // bool sent = seller.send(itemPrice);
  }

  // 1. Add modifiers to check:
  //    - the item is sold already 
  //    - the person calling this function is the seller. 
  // 2. Change the state of the item to shipped. 
  // 3. call the event associated with this function!

  /** Ship an item */
  function shipItem(uint _sku) public
    sold(_sku) isSeller(_sku) {

      items[_sku].state = State.Shipped;
      emit LogShipped(_sku);
  }

  // 1. Add modifiers to check 
  //    - the item is shipped already 
  //    - the person calling this function is the buyer. 
  // 2. Change the state of the item to received. 
  // 3. Call the event associated with this function!

  /** Receive and item */
  function receiveItem(uint _sku) public 
    shipped(_sku) isBuyer(_sku) {

      items[_sku].state = State.Received;
      emit LogReceived(_sku);
  }

  // Uncomment the following code block. it is needed to run tests
  /** Fetch an item - helper function for tests */
  function fetchItem(uint _sku) public view
     returns (string memory name, uint sku, uint price, uint state, address seller, address buyer) {
     name = items[_sku].name;
     sku = items[_sku].sku;
     price = items[_sku].price;
     state = uint(items[_sku].state);
     seller = items[_sku].seller;
     buyer = items[_sku].buyer;
     return (name, sku, price, state, seller, buyer);
  }
}  // end of contract SupplyChain
