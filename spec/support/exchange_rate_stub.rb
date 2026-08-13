# Ai::Concerns::Pricing fetches a live USD→MXN rate in its class body, so the
# call fires whenever that constant first autoloads. WebMock::NetConnectNotAllowedError
# does not descend from StandardError, so the rescue in fetch_live_exchange_rate
# does not catch it: whether a spec passed depended on whether some earlier file
# had already required webmock/rspec and autoloaded Pricing. Stubbing the request
# makes that load deterministic in any order.
RSpec.configure do |config|
  config.before do
    next unless defined?(WebMock)

    WebMock.stub_request(:get, "https://open.er-api.com/v6/latest/USD")
           .to_return(
             status: 200,
             body: { "rates" => { "MXN" => 18.5 } }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end
end
