require_relative "../lib/an"
require "securerandom"
require "benchmark"

AN.login_id = ENV["LOGIN_ID"]
AN.transaction_key = ENV["TRANS_KEY"]

setup do
  customer = AN::Customer.new(first_name: "John",
                                        last_name: "Doe",
                                        zip: "98004",
                                        email: "me@cyrildavid.com")

  invoice = AN::Invoice.new(invoice_num: SecureRandom.hex(20),
                                      amount: "19.99",
                                      description: "Sample Transaction")

  card = AN::CreditCard.new(card_num: "4111111111111111",
                                      card_code: "123",
                                      exp_month: "1", exp_year: "2015")

  [customer, invoice, card]
end

test "straight up sale" do |customer, invoice, card|
  gateway = AN::AIM.test
  response = gateway.sale(customer, invoice, card)

  assert_equal "1", response["code"]
end

test "wrong credit card number" do |customer, invoice, card|
  gateway = AN::AIM.test
  card.card_num = "4111222233334444"

  ex = nil

  begin
    gateway.sale(customer, invoice, card)
  rescue Exception => e
    ex = e
  end

  assert ex.kind_of?(AN::TransactionFailed)
  assert_equal "6", ex.response["reason_code"]
  assert_equal "The credit card number is invalid.", ex.response["reason_text"]
end

test "authorize and capture" do |customer, invoice, card|
  gateway = AN::AIM.test
  auth = gateway.authorize(customer, invoice, card)
  capt = gateway.capture(auth["trans_id"])

  assert_equal "1", capt["code"]
end

test "authorize and void" do |customer, invoice, card|
  gateway = AN::AIM.test
  auth = gateway.authorize(customer, invoice, card)
  void = gateway.void(auth["trans_id"])

  assert_equal "1", void["code"]
end
