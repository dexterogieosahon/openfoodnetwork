require 'open_food_network/split_products_by_distribution'

Spree::TaxonsController.class_eval do
  include EnterprisesHelper
  include OrderCyclesHelper
  include OpenFoodNetwork::SplitProductsByDistribution

  before_filter :require_distributor_chosen, only: :show

  respond_override :show => { :html => { :success => lambda {
        @products, @products_local, @products_remote = split_products_by_distribution @products, current_distributor, current_order_cycle
      } } }
end
