# frozen_string_literal: true

module Spree
  class OrderInventory
    attr_accessor :order

    def initialize(order)
      @order = order
    end

    # Only verify inventory for completed orders (as orders in frontend checkout
    # have inventory assigned via +order.create_proposed_shipment+) or when
    # shipment is explicitly passed
    #
    # In case shipment is passed the stock location should only unstock or
    # restock items if the order is completed. That is so because stock items
    # are always unstocked when the order is completed through +shipment.finalize+
    def verify(line_item, shipment = nil)
      if order.completed? || shipment.present?

        variant_units = inventory_units_for(line_item.variant)

        if variant_units.size < line_item.quantity
          quantity = line_item.quantity - variant_units.size

          shipment ||= determine_target_shipment(line_item.variant)
          add_to_shipment(shipment, line_item.variant, quantity)
        elsif variant_units.size > line_item.quantity
          remove(line_item, variant_units, shipment)
        end
      else
        true
      end
    end

    def inventory_units_for(variant)
      units = order.shipments.collect{ |s| s.inventory_units.to_a }.flatten
      units.group_by(&:variant_id)[variant.id] || []
    end

    private

    def remove(line_item, variant_units, shipment = nil)
      quantity = variant_units.size - line_item.quantity

      if shipment.present?
        remove_from_shipment(shipment, line_item.variant, quantity, line_item.restock_item)
      else
        order.shipments.each do |each_shipment|
          break if quantity == 0

          quantity -= remove_from_shipment(each_shipment,
                                           line_item.variant,
                                           quantity,
                                           line_item.restock_item)
        end
      end
    end

    # Returns either one of the shipment:
    #
    # first unshipped that already includes this variant
    # first unshipped that's leaving from a stock_location that stocks this variant
    def determine_target_shipment(variant)
      target_shipment = order.shipments.detect do |shipment|
        (shipment.ready? || shipment.pending?) && shipment.contains?(variant)
      end

      target_shipment || order.shipments.detect do |shipment|
        (shipment.ready? || shipment.pending?) &&
          variant.stock_location_ids.include?(shipment.stock_location_id)
      end
    end

    def add_to_shipment(shipment, variant, quantity)
      on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

      on_hand.times { shipment.set_up_inventory('on_hand', variant, order) }
      back_order.times { shipment.set_up_inventory('backordered', variant, order) }

      # adding to this shipment, and removing from stock_location
      if order.completed?
        shipment.stock_location.unstock(variant, quantity, shipment)
      end

      quantity
    end

    def remove_from_shipment(shipment, variant, quantity, restock_item)
      return 0 if quantity == 0 || shipment.shipped?

      shipment_units = shipment.inventory_units_for(variant).reject do |variant_unit|
        variant_unit.state == 'shipped'
      end.sort_by(&:state)

      removed_quantity = 0

      shipment_units.each do |inventory_unit|
        break if removed_quantity == quantity

        inventory_unit.destroy
        removed_quantity += 1
      end
      shipment.destroy if shipment.inventory_units.reload.count == 0

      # removing this from shipment, and adding to stock_location
      if order.completed? && restock_item
        shipment.stock_location.restock variant, removed_quantity, shipment
      end

      removed_quantity
    end
  end
end
