RSpec.describe OpenAI::Client do
  describe "#finetunes", :vcr do
    let(:filename) { "sentiment.jsonl" }
    let(:file) { File.join(RSPEC_ROOT, "fixtures/files", filename) }
    let!(:file_id) do
      response = VCR.use_cassette("finetunes files upload ") do
        OpenAI::Client.new.files.upload(parameters: { file: file, purpose: "fine-tune" })
      end
      JSON.parse(response.body)["id"]
    end
    let(:model) { "ada" }
    let!(:create_response) do
      VCR.use_cassette("#{cassette} create") do
        OpenAI::Client.new.finetunes.create(
          parameters: {
            training_file: file_id,
            model: model
          }
        )
      end
    end
    let(:create_id) { create_response.parsed_response["id"] }

    describe "#create" do
      let(:cassette) { "finetunes" }

      it "succeeds" do
        expect(create_response.parsed_response["object"]).to eq("fine-tune")
      end
    end

    describe "#list" do
      let(:cassette) { "finetunes list" }
      let(:response) { OpenAI::Client.new.finetunes.list }

      it "succeeds" do
        VCR.use_cassette(cassette) do
          r = JSON.parse(response.body)
          expect(r["data"][0]["object"]).to eq("fine-tune")
        end
      end
    end

    describe "#retrieve" do
      let(:cassette) { "finetunes retrieve" }
      let(:response) { OpenAI::Client.new.finetunes.retrieve(id: create_id) }

      it "succeeds" do
        VCR.use_cassette(cassette) do
          r = JSON.parse(response.body)
          expect(r["object"]).to eq("fine-tune")
        end
      end
    end

    describe "#cancel" do
      let(:cassette) { "finetunes cancel" }
      let(:response) { OpenAI::Client.new.finetunes.cancel(id: create_id) }

      it "succeeds" do
        VCR.use_cassette(cassette) do
          r = JSON.parse(response.body)
          expect(r["id"]).to eq(create_id)
          expect(r["status"]).to eq("cancelled")
        end
      end
    end

    describe "#events" do
      let(:cassette) { "finetunes events" }
      let(:response) { OpenAI::Client.new.finetunes.events(id: create_id) }

      it "succeeds" do
        VCR.use_cassette(cassette) do
          r = JSON.parse(response.body)
          expect(r["data"][0]["object"]).to eq("fine-tune-event")
        end
      end
    end

    describe "#delete" do
      let(:cassette) { "finetunes delete" }
      let(:retrieve_cassette) { "#{cassette} retrieve" }
      let(:response) { OpenAI::Client.new.finetunes.delete(fine_tuned_model: fine_tuned_model) }
      let(:fine_tuned_model) do
        VCR.use_cassette(retrieve_cassette) do
          OpenAI::Client.new.finetunes.retrieve(id: create_id)["fine_tuned_model"]
        end
      end

      before do
        # We need to check the fine-tune model has been created by OpenAI
        # before we can delete it.
        retrieved = VCR.use_cassette(retrieve_cassette) do
          OpenAI::Client.new.finetunes.retrieve(id: create_id)
        end
        until retrieved.parsed_response["status"] == "succeeded"
          sleep(1)
          retrieved = VCR.use_cassette(retrieve_cassette, record: :all) do
            OpenAI::Client.new.finetunes.retrieve(id: create_id)
          end
        end
      end

      it "succeeds" do
        VCR.use_cassette(cassette) do
          r = JSON.parse(response.body)
          expect(r["deleted"]).to eq(true)
        end
      end

      context "when passing a fine-tune ID instead of the model name" do
        it "raises an error" do
          expect do
            OpenAI::Client.new.finetunes.delete(fine_tuned_model: create_id)
          end.to raise_error(ArgumentError)
        end
      end
    end

    describe "#completions" do
      let(:prompt) { "I love Mondays" }
      let(:cassette) { "finetune completions #{prompt}".downcase }
      let(:model) { "ada:ft-user-jxm65ijkzc1qrfhc0ij8moic-2021-12-11-20-11-52" }
      let(:response) do
        OpenAI::Client.new.completions(
          parameters: {
            model: model,
            prompt: prompt
          }
        )
      end

      it "succeeds" do
        VCR.use_cassette(cassette) do
          expect(JSON.parse(response.body)["model"]).to eq(model)
        end
      end
    end
  end
end
