# frozen_string_literal: true

module Spree
  class ShippingMethodCategory < ApplicationRecord
    self.belongs_to_required_by_default = false

    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory',
                                   inverse_of: :shipping_method_categories
  end
end
