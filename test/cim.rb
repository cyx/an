require_relative "helper"

test do
  gateway = AN::CIM.test

  id = SecureRandom.hex(10)
  ref_id = SecureRandom.hex(10)

  resp = gateway.create_customer(customer_id: id,
                                 ref_id: ref_id, email: "foo@bar.com",
                                 description: "Mr Foo")

  assert resp.success?
  assert_equal ref_id, resp.ref_id

  profile_id = resp.profile_id

  resp = gateway.create_payment_profile(profile_id: profile_id,
                                        first_name: "John",
                                        last_name: "Doe",
                                        company: "",
                                        address: "#12345 Foobar street",
                                        city: "Los Angeles",
                                        state: "CA",
                                        zip: "90210",
                                        country: "US",
                                        phone: "",
                                        fax: "",
                                        card_num: "4111111111111111",
                                        exp_date: "2015-01",
                                        validation_mode: "liveMode")

  assert resp.success?
  assert resp.payment_response.success?

  payment_profile_id = resp.payment_profile_id

  invoice_num = SecureRandom.hex(10)

  resp = gateway.create_transaction(profile_id: profile_id,
                                    payment_profile_id: payment_profile_id,
                                    amount: "11.95",
                                    invoice_num: invoice_num,
                                    description: "Jan - Feb",
                                    purchase_order_number: "001",
                                    tax_exempt: true,
                                    recurring_billing: false)


  assert resp.success?
  assert resp.payment_response.success?
end
