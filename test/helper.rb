require "cutest"
require "securerandom"
require_relative "../lib/an"

AN.login_id = ENV["LOGIN_ID"]
AN.transaction_key = ENV["TRANS_KEY"]
