module Oca
  module Epak
    class Client < BaseClient
      ONE_STRING = "1".freeze
      USER_STRING = "usr".freeze
      PASSWORD_STRING = "psw".freeze
      WSDL_URL = "#{BASE_WSDL_URL}/epak_tracking/Oep_TrackEPak.asmx?wsdl".freeze

      def initialize(username, password)
        super
        @opts = { wsdl: WSDL_URL }.merge(Oca::Logger.options)
        @client = Savon.client(@opts)
      end

      # Checks if the user has input valid credentials
      #
      # @return [Boolean] Whether the credentials entered are valid or not
      def check_credentials
        method = :get_epack_user
        opts = { USER_STRING => username, PASSWORD_STRING => password }
        response = client.call(method, message: opts)

        parse_result(response, method)[:existe] == ONE_STRING
      end

      # Creates a Pickup Order, which lets OCA know you want to make a delivery.
      #
      # @see https://github.com/ombulabs/oca-epak/blob/master/doc/OCAWebServices.pdf
      #
      # @param [Hash] opts
      # @option opts [Oca::Epak::PickupData] :pickup_data Pickup Data object
      # @option opts [Boolean] :confirm_pickup Confirm Pickup? Defaults to false
      # @option opts [Integer] :days_to_pickup Days OCA should wait before pickup, default: 1
      # @option opts [Integer] :pickup_range Range to be used when picking it up, default: 1
      # @return [Hash, nil]
      def create_pickup_order(opts = {})
        confirm_pickup = opts.fetch(:confirm_pickup, FALSE_STRING)
        days_to_pickup = opts.fetch(:days_to_pickup, ONE_STRING)
        pickup_range = opts.fetch(:pickup_range, ONE_STRING)
        rendered_xml = opts[:pickup_data].to_xml

        message = { USER_STRING => username, PASSWORD_STRING => password,
                    "xml_Datos" => rendered_xml,
                    "ConfirmarRetiro" => confirm_pickup.to_s,
                    "DiasHastaRetiro" => days_to_pickup,
                    "idFranjaHoraria" => pickup_range }
        response = client.call(:ingreso_or, message: message)
        parse_result(response, :ingreso_or)
      end

      # Creates multiple Pickups or Admisions (Deliveries) Orders, which lets OCA know you want to
      # make some deliveries grouped by origin.
      #
      # @see https://github.com/ombulabs/oca-epak/blob/master/doc/OCAWebServices.pdf
      #
      # @param [Hash] opts
      # @option opts [Oca::Epak::MultipleDeliveriesData] :deliveries_data Multiple Deliveries Data
      # object
      # @option opts [Boolean] :confirm_deliveries Confirm Deliveries? Defaults to false
      # @return [Hash, nil]
      def create_multiple_delivery_orders(opts = {})
        confirm_deliveries = opts.fetch(:confirm_deliveries, FALSE_STRING)
        rendered_xml = opts[:deliveries_data].to_xml

        message = { USER_STRING => username, PASSWORD_STRING => password,
                    "xml_Datos" => rendered_xml,
                    "ConfirmarRetiro" => confirm_deliveries.to_s }

        response = client.call(:ingreso_or_multiples_retiros, message: message)
        parse_result(response, :ingreso_or_multiples_retiros)
      end

      # Cancel a Delivery Order
      #
      # @param [String] The ID of the Delivery Order
      # @return [Hash] { id_result: "", mensaje: "" }
      def cancel_delivery_order(delivery_order_id)
        method = :anular_orden_generada
        message = {
          USER_STRING => username,
          PASSWORD_STRING => password,
          "IdOrdenRetiro" => delivery_order_id.to_s
        }

        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Returns the information about a Delivery Order using the :order_operation_code
      #
      # @param [String] Value at "CodigoOperacion" when creating a Delivery Order
      # @return [Hash, nil]
      def get_order_result(order_operation_code)
        method = :get_or_result
        message = {
          USER_STRING.capitalize => username,
          PASSWORD_STRING.capitalize => password,
          "idCabecera" => order_operation_code.to_s
        }

        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Get rates and delivery estimate for a shipment
      #
      # @param [Hash] opts
      # @option opts [String] :total_weight Total Weight e.g: 20
      # @option opts [String] :total_volume Total Volume e.g: 0.0015
      #                                (0.1mts * 0.15mts * 0.1mts)
      # @option opts [String] :origin_zip_code Origin ZIP Code
      # @option opts [String] :destination_zip_code Destination ZIP Code
      # @option opts [String] :declared_value Declared Value
      # @option opts [String] :package_quantity Quantity of Packages
      # @option opts [String] :cuit Client's CUIT e.g: 30-99999999-7
      # @option opts [String] :operation_code Operation Type
      # @return [Hash, nil] Contains Total Price, Delivery Estimate
      def get_shipping_rate(opts = {})
        method = :tarifar_envio_corporativo
        message = { "PesoTotal" => opts[:total_weight],
                    "VolumenTotal" => opts[:total_volume],
                    "CodigoPostalOrigen" => opts[:origin_zip_code],
                    "CodigoPostalDestino" => opts[:destination_zip_code],
                    "ValorDeclarado" => opts[:declared_value],
                    "CantidadPaquetes" => opts[:package_quantity],
                    "Cuit" => opts[:cuit],
                    "Operativa" => opts[:operation_code] }
        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Returns the actual status and other info about the delivery if exists
      # and is not cancelled
      #
      # @param [Hash] opts
      # @option opts [String] :tracking_code Tracking Code
      # @option opts [String] :delivery_order_id ID of the Delivery Order
      # @return [Hash, nil] Contains delivery information as prices, insurance
      # package sice and actual status information
      def get_delivery_status(opts = {})
        method = :get_envio_estado_actual
        message = {}.tap do |hash|
          hash["numeroEnvio"] = opts[:tracking_code].to_s if opts[:tracking_code]
          hash["ordenRetiro"] = opts[:delivery_order_id].to_s if opts[:delivery_order_id]
        end

        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Returns all existing Taxation Centers
      #
      # @return [Array, nil] Information for all the Oca Taxation Centers
      def taxation_centers
        method = :get_centros_imposicion
        response = client.call(method)
        parse_result(response, method)
      end

      # Returns all operation codes
      #
      # @return [Array, nil] Returns all operation codes available for the user
      def get_operation_codes
        method = :get_operativas_by_usuario
        message = {
          USER_STRING => username,
          PASSWORD_STRING => password
        }
        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Given a client's CUIT with a range of dates, returns a list with
      # all shipments made within the given period.
      #
      # @param [String] Client's CUIT
      # @param [String] "From date" in DD-MM-YYYY format
      # @param [String] "To date" in DD-MM-YYYY format
      # @return [Array, nil] Contains an array of hashes with NroProducto and NumeroEnvio
      def list_shipments(opts = {})
        seconds_in_a_day = 86400
        since_date = opts[:since_date] || (Time.now - 7 * seconds_in_a_day).strftime("%d-%m-%Y")
        until_date = opts[:until_date] || Time.now.strftime("%d-%m-%Y")

        method = :list_envios
        message = {
          "CUIT" => opts[:cuit],
          "FechaDesde" => since_date,
          "FechaHasta" => until_date
        }

        response = client.call(method, message: message)
        parse_result(response, method)
      end

      # Returns all provinces in Argentina
      #
      # @return [Array, nil] Provinces in Argentina with their ID and name as a Hash
      def provinces
        method = :get_provincias
        response = client.call(method)

        parse_result(response, method)
      end
    end
  end
end
