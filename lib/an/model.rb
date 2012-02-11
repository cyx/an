require "scrivener"

module AN
  class Model < Scrivener
    # This is an Authorize.net specific implementation detail,
    # basically all their field names are prefixed with an `x_`.
    def to_hash
      {}.tap do |ret|
        attributes.each do |att, val|
          ret["x_#{att}"] = val
        end
      end
    end
  end

  class CreditCard < Model
    attr_accessor :card_num
    attr_accessor :card_code
    attr_accessor :exp_month
    attr_accessor :exp_year

    def validate
      assert_present(:card_num) &&
        assert(Luhn.check(card_num), [:card_num, :not_valid])

      assert_present(:card_code)

      assert_format(:exp_month, /\A\d{1,2}\z/) &&
        assert_format(:exp_year, /\A\d{4}\z/) &&
          assert(exp_in_future, [:exp_date, :not_valid])
    end

    # Convert to the expiry date expected by the API which is in MMYY.
    def exp_date
      y = "%.4i" % exp_year
      m = "%.2i" % exp_month

      "#{m}#{y[-2..-1]}"
    end

    # Because the expected parameters are significantly different
    # than what we have for free from `Model`, it's much
    # simpler to just write our own `to_hash` here.
    def to_hash
      { "x_card_num" => card_num, "x_card_code" => card_code,
        "x_exp_date" => exp_date }
    end

  private
    def exp_in_future
      Time.new(exp_year, exp_month) > Time.now
    end
  end

  class Customer < Model
    attr_accessor :first_name
    attr_accessor :last_name
    attr_accessor :address
    attr_accessor :state
    attr_accessor :zip
    attr_accessor :email

    def validate
      assert_present :first_name
      assert_present :last_name
    end
  end

  class Invoice < Model
    attr_accessor :invoice_num
    attr_accessor :amount
    attr_accessor :description

    def amount=(amount)
      if amount.nil? || amount.empty?
        @amount = nil
      else
        @amount = "%.2f" % amount
      end
    end

    def validate
      assert_present(:invoice_num) && assert_length(:invoice_num, 1..20)
      assert_present(:amount)
      assert_present(:description)
    end
  end

  # @see http://en.wikipedia.org/wiki/Luhn_algorithm
  # @credit https://gist.github.com/1182499
  module Luhn
    RELATIVE_NUM = { '0' => 0, '1' => 2, '2' => 4, '3' => 6, '4' => 8,
                     '5' => 1, '6' => 3, '7' => 5, '8' => 7, '9' => 9 }

    def self.check(number)
      number = number.to_s.gsub(/\D/, "").reverse

      sum = 0

      number.split("").each_with_index do |n, i|
        sum += (i % 2 == 0) ? n.to_i : RELATIVE_NUM[n]
      end

      sum % 10 == 0
    end
  end
end
