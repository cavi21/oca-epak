RSpec.describe Oca::BaseClient do
  let(:username) { "hey@you.com" }
  let(:password) { "654321" }

  subject { Oca::BaseClient.new(username, password) }

  describe "#parse_result" do
    let(:method_name) { :method_name }
    let(:key) { "NewDataSet" }
    let(:topic) { "Table" }
    let(:result_key) { :new_data_set }
    let(:result_topic) { :table}
    let(:schema) do
      {
        :@id => key,
        :element=> {
          :complex_type => {
            :choice => {
              :element => { :@name => topic }
            }
          }
        }
    }
    end
    let(:body) do
      {:method_name_response=>
        {:method_name_result=>
          {
            :schema=>  schema,
            :diffgram=> { result_key=> { result_topic=> [{ :foo=>"bar" }] } }
          }
        }
      }
    end
    let(:invalid_body) do
      {:method_name_response=>
        {:method_name_result=>
          {
            :schema=>  schema,
            :diffgram=> { :foo=>"bar" }
          }
        }
      }
    end
    let(:oca_response) { double("Savon::Response", body: body) }
    let(:invalid_oca_response) { double("Savon::Response", body: invalid_body) }

    it "returns the contents of a hash in the Oca response" do
      result = subject.send(:parse_result, oca_response, method_name)
      expected_result = [{ foo: "bar" }]
      expect(result).to eq(expected_result)
    end

    it "returns nil if the response doesn't contain the expected keys" do
      result = subject.send(:parse_result, invalid_oca_response, method_name)
      expect(result).to be_nil
    end
  end
end
