module Oca
  module Epak
    class MultipleDeliveriesData
      PATH_TO_XML = File.expand_path("../templates/multiple_deliveries.xml.erb", __FILE__).freeze

      attr_accessor :account_number, :deliveries

      # Creates a Multiple Deliveries Data object for creating multiples pickup or adminsions
      # orders in OCA grouped by the origin of the shipments.
      #
      # @param [Hash] opts
      # @option opts [String] :account_number Account Number (SAP)
      # @option opts [Hash] :deliveries Deliveries Hash in which the keys are the 'origin' of the
      # 'shipments' Array that is the value. The structure should look like this:
      # {
      #   { 'calle' => '', [...] } => [
      #     {
      #       'id_operativa' => '',
      #       'numero_remito' => '',
      #       'destinatario' => {
      #         'apellido' => '', [...]
      #       },
      #       'paquetes' => [
      #         { 'alto' => '', [...] },
      #         { [...] }
      #       ]
      #     },
      #     { [...] },
      #   ]
      # }
      def initialize(opts = {})
        self.account_number = opts[:account_number]
        self.deliveries = opts[:deliveries]
      end

      def to_xml
        multiple_or_template.result(binding)
      end

      private

        def multiple_or_template
          ERB.new(File.read(PATH_TO_XML), nil, "-")
        end
    end
  end
end
