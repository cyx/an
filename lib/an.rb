module AN
  require_relative "an/client"
  require_relative "an/model"
  require_relative "an/aim"
  require_relative "an/cim"

  class << self
    attr_accessor :login_id
    attr_accessor :transaction_key
  end

  class PaymentResponse
    RESPONSE_FIELDS = %w[code subcode reason_code reason_text
                         authorization_code avs_response trans_id
                         invoice_number description amount method
                         transaction_type customer_id first_name
                         last_name company address city state zip
                         country phone fax email
                         shipping_first_name shipping_last_name
                         shipping_company shipping_address shipping_city
                         shipping_state shipping_zip shipping_country
                         tax duty freight tax_exempt purchase_order_number
                         md5_hash card_code_response cavv_response
                         account_number card_type split_tender_id
                         requested_amount balance_on_card]

    attr :fields

    def initialize(data, delimiter = ",")
      @fields = Hash[RESPONSE_FIELDS.zip(data.split(delimiter))]

    end

    def success?
      fields["code"] == "1" && fields["reason_code"] == "1"
    end

    def code
      fields["code"]
    end

    def message
      fields["reason_text"]
    end

    def trans_id
      fields["trans_id"]
    end
  end
end
