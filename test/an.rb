require_relative "helper"

test "luhn check" do
  assert AN::Luhn.check("4111111111111111")
  assert ! AN::Luhn.check("4111111111111112")
end

# AIM (Advanced Integration Method)
scope do
  setup do
    AN.connect
  end

  test "AIM most basic transaction" do |gateway|
    resp = gateway.transact(
      card_number: "4111111111111111",
      card_code: "123",
      expiration_date: "2015-01",
      amount: "10.00",
      invoice_number: SecureRandom.hex(10)
    )

    assert resp.success?
    assert resp["transactionResponse"].kind_of?(Hash)
    assert_equal "XXXX1111", resp["transactionResponse"]["accountNumber"]
    assert_equal "Visa", resp["transactionResponse"]["accountType"]
  end

  test "AIM transaction with billing info" do |gateway|
    resp = gateway.transact(
      card_number: "4111111111111111",
      card_code: "123",
      expiration_date: "2015-01",
      amount: "10.00",
      invoice_number: SecureRandom.hex(10),
      description: "Aeutsahoesuhtaeu",
      first_name: "John",
      last_name: "Doe",
      address: "12345 foobar street",
      zip: "90210"
    )

    assert resp.success?
    assert resp["transactionResponse"].kind_of?(Hash)
    assert_equal "XXXX1111", resp["transactionResponse"]["accountNumber"]
    assert_equal "Visa", resp["transactionResponse"]["accountType"]
  end
end

# CIM (Customer Information Manager)
scope do
  test do |gateway|
    reference_id = SecureRandom.hex(10)
    customer_id  = SecureRandom.hex(10)

    # So this step ideally should be done in a background process
    # after the user on your site signs up.
    resp = gateway.create_profile(reference_id: reference_id,
                                  customer_id: customer_id,
                                  email: "foo@bar.com")

    assert resp.success?
    assert_equal reference_id, resp["refId"]
    assert resp.profile_id

    # After a successful response in the background process, you
    # should store the profile id in your User hash / table / relation.
    profile_id = resp.profile_id

    # Now this happens when the customer provides his credit card details
    # the first time he tries to go into a page or resource that requires
    # a form of payment. For example in heroku, you need to add a credit
    # card as soon as you try to use any kind of add-on.
    resp = gateway.create_payment_profile(profile_id: profile_id,
                                          first_name: "Quentin",
                                          last_name: "Tarantino",
                                          card_number: "4111111111111111",
                                          card_code: "123",
                                          address: "#12345 Foobar street",
                                          zip: "90210",
                                          expiration_date: "2015-01")

    # If you're to allow the entry of this payment profile, then you
    # should verify 2 things:
    #
    # 1. the actual response is successful
    # 2. the payment response is successful.
    #
    # By default the validation method used is liveMode which returns an
    # AIM-like payment response string related to the credit card details
    # passed as part of creating the payment profile.
    assert resp.success?
    assert resp.payment_profile_id
    assert resp.authorization.success?

    assert_equal "XXXX1111", resp.authorization["accountNumber"]
    assert_equal "Visa", resp.authorization["accountType"]

    # The payment profile id should then be saved together with the user.
    # You may also do a one-to-many setup similar to amazon where they can
    # add multiple credit cards. If that's the case, simply use the
    # account_number / card type in order to let the customer identify
    # which credit card is which.
    payment_profile_id = resp.payment_profile_id

    # Now this should be executed when the customer does a one-click
    # payment option similar to amazon, or when the end of month utility
    # bill is due (i.e. AWS / Heroku).
    resp = gateway.create_profile_transaction({
      profile_id: profile_id,
      payment_profile_id: payment_profile_id,
      amount: "11.95",
      invoice_number: SecureRandom.hex(10),
      description: "Jan - Feb",
      purchase_order_number: "001"
    })

    assert resp.success?
    assert resp.authorization.success?
    assert_equal "XXXX1111", resp.authorization["accountNumber"]
    assert_equal "Visa", resp.authorization["accountType"]
  end
end
