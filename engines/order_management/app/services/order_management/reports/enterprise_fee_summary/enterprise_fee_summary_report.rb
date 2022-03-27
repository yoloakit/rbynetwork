# frozen_string_literal: true

module OrderManagement
  module Reports
    module EnterpriseFeeSummary
      class EnterpriseFeeSummaryReport
        attr_accessor :permissions, :parameters, :user

        def initialize(user, params = {}, render_table = false)
          p = params[:q]
          if p.present?
            p['start_at'] = p.delete('completed_at_gt')
            p['end_at'] = p.delete('completed_at_lt')
          end
          @parameters = OrderManagement::Reports::EnterpriseFeeSummary::Parameters.new(p || {})
          @parameters.validate!
          @user = user
          @render_table = render_table
          @permissions = Permissions.new(user)
          @parameters.authorize!(@permissions)
        end

        def table_headers
          data_row_attributes.map do |attribute|
            header_label(attribute)
          end
        end

        def table_rows
          return [] unless @render_table

          enterprise_fee_type_total_list.sort.map do |data|
            data_row_attributes.map do |attribute|
              data.public_send(attribute)
            end
          end
        end

        # This report does not use ransack search, but all other are, so creating a fake
        # Ransack search at least for the view to display correctly the selected
        # ransack params like completed_at_gt and completed_at_lt
        def search
          Spree::Order.where('1=2').ransack(parameters)
        end

        private

        def data_row_attributes
          [
            :fee_type,
            :enterprise_name,
            :fee_name,
            :customer_name,
            :fee_placement,
            :fee_calculated_on_transfer_through_name,
            :tax_category_name,
            :total_amount
          ]
        end

        def header_label(attribute)
          I18n.t("header.#{attribute}", scope: i18n_scope)
        end

        def i18n_scope
          "order_management.reports.enterprise_fee_summary.formats.csv"
        end

        def enterprise_fees_by_customer
          if parameters.order_cycle_ids.empty?
            # Always restrict to permitted order cycles
            parameters.order_cycle_ids = permissions.allowed_order_cycles.map(&:id)
          end
          Scope.new.apply_filters(parameters).result
        end

        def enterprise_fee_type_total_list
          enterprise_fees_by_customer.map do |total_data|
            summarizer = Summarizer.new(total_data)

            ReportData::EnterpriseFeeTypeTotal.new.tap do |total|
              enterprise_fee_type_summarizer_to_total_attributes.each do |attribute|
                total.public_send("#{attribute}=", summarizer.public_send(attribute))
              end
            end
          end
        end

        def enterprise_fee_type_summarizer_to_total_attributes
          [
            :fee_type, :enterprise_name, :fee_name, :customer_name, :fee_placement,
            :fee_calculated_on_transfer_through_name, :tax_category_name, :total_amount
          ]
        end
      end
    end
  end
end
