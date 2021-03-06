require 'spec_helper'

feature %q{
    As a consumer
    I want to choose a distributor when adding products to my cart
    So that I can avoid making an order from many different distributors
} do
  include AuthenticationWorkflow
  include WebHelper

  context "with product distribution" do
    scenario "adding a product to the cart with no distributor chosen" do
      # Given a product and some distributors
      d1 = create(:distributor_enterprise)
      d2 = create(:distributor_enterprise)
      p = create(:product, :distributors => [d1])
      create(:product, :distributors => [d2])

      # When I add an item to my cart without choosing a distributor
      visit spree.product_path p
      click_button 'Add To Cart'

      # Then I should see an error message
      page.should have_content "That product is not available from the chosen distributor or order cycle"

      # And the product should not have been added to my cart
      Spree::Order.last.line_items.should be_empty
    end

    context "adding a subsequent product to the cart" do
      it "does not allow the user to add a product from a distributor that cannot supply the cart's products" do
        # Given two products, each at a different distributor
        d1 = create(:distributor_enterprise)
        d2 = create(:distributor_enterprise)
        p1 = create(:product, :distributors => [d1])
        p2 = create(:product, :distributors => [d2])

        # When I add one of them to my cart
        select_distribution d1
        visit spree.product_path p1
        click_button 'Add To Cart'

        # And I attempt to add the other
        visit spree.product_path p2

        # Then I should not be allowed to add the product
        page.should_not have_selector "button#add-to-cart-button"
        page.should have_content "Please complete your order at #{d1.name} before shopping with another distributor."
      end
    end

    describe 'with order cycles disabled' do
      before(:each) do
        OrderCyclesHelper.class_eval do
          def order_cycles_enabled?
            false
          end
        end
      end

      scenario "should not show order cycle details when adding to cart" do
        # Given a product and a distributor
        d = create(:distributor_enterprise)
        p = create(:product, :price => 12.34)

        # When I add an item to my cart
        visit spree.product_path p

        page.should_not have_selector '#order_cycle_id option'
      end

    end
  end

  context "with order cycle distribution" do
    before(:each) do
      OrderCyclesHelper.class_eval do
        def order_cycles_enabled?
          true
        end
      end
    end

    scenario "adding a product to the cart with no distribution chosen" do
      # Given a product and some distributors
      d1 = create(:distributor_enterprise)
      d2 = create(:distributor_enterprise)
      p1 = create(:product)
      p2 = create(:product)
      create(:simple_order_cycle, :distributors => [d1], :variants => [p1.master])
      create(:simple_order_cycle, :distributors => [d2], :variants => [p2.master])

      # When I add an item to my cart without choosing a distributor or order cycle
      visit spree.product_path p1
      click_button 'Add To Cart'

      # Then I should see an error message
      page.should have_content "Please choose an order cycle for this order."

      # And the product should not have been added to my cart
      Spree::Order.last.line_items.should be_empty
    end

    scenario "adding the first product to the cart" do
      # Given a product and a distributor
      d = create(:distributor_enterprise)
      p = create(:product, :price => 12.34)
      oc = create(:simple_order_cycle, :distributors => [d], :variants => [p.master])

      # When I add an item to my cart
      select_distribution d, oc
      visit spree.product_path p
      click_button 'Add To Cart'

      # Then the correct totals should be displayed
      page.should have_selector 'span.item-total', :text => '$12.34'

      # TODO: Test these when order cycle fees is implemented
      # page.should have_selector 'span.distribution-total', :text => '$1.23'
      # page.should have_selector 'span.grand-total', :text => '$13.57'

      # And the item should be in my cart
      order = Spree::Order.last
      line_item = order.line_items.first
      line_item.product.should == p

      # And my order should have its distributor and order cycle set to the chosen ones
      order.distributor.should == d
      order.order_cycle.should == oc
    end
  end

  context "group buys" do
    scenario "adding a product to the cart for a group buy" do
      # Given a group buy product and a distributor
      d = create(:distributor_enterprise)
      p = create(:product, :distributors => [d], :group_buy => true)

      # When I add the item to my cart
      select_distribution d
      visit spree.product_path p
      fill_in "variants_#{p.master.id}", :with => 2
      fill_in "variant_attributes_#{p.master.id}_max_quantity", :with => 3
      click_button 'Add To Cart'

      # Then the item should be in my cart with correct quantities
      order = Spree::Order.last
      li = order.line_items.first
      li.product.should == p
      li.quantity.should == 2
      li.max_quantity.should == 3
    end

    scenario "adding a product with variants to the cart for a group buy" do
      # Given a group buy product with variants and a distributor
      d = create(:distributor_enterprise)
      p = create(:product, :distributors => [d], :group_buy => true)
      create(:variant, :product => p)

      # When I add the item to my cart
      select_distribution d
      visit spree.product_path p
      fill_in "quantity", :with => 2
      fill_in "max_quantity", :with => 3
      click_button 'Add To Cart'

      # Then the item should be in my cart with correct quantities
      order = Spree::Order.last
      li = order.line_items.first
      li.product.should == p
      li.quantity.should == 2
      li.max_quantity.should == 3
    end

    scenario "adding a product to cart that is not a group buy does not show max quantity field" do
      # Given a group buy product and a distributor
      d = create(:distributor_enterprise)
      p = create(:product, :distributors => [d], :group_buy => false)

      # When I view the add to cart form, there should not be a max quantity field
      visit spree.product_path p

      page.should_not have_selector "#variant_attributes_#{p.master.id}_max_quantity"
    end

    scenario "adding a product with a max quantity less than quantity results in max_quantity==quantity" do
      # Given a group buy product and a distributor
      d = create(:distributor_enterprise)
      p = create(:product, :distributors => [d], :group_buy => true)

      # When I add the item to my cart
      select_distribution d
      visit spree.product_path p
      fill_in "variants_#{p.master.id}", :with => 2
      fill_in "variant_attributes_#{p.master.id}_max_quantity", :with => 1
      click_button 'Add To Cart'

      # Then the item should be in my cart with correct quantities
      order = Spree::Order.last
      li = order.line_items.first
      li.product.should == p
      li.quantity.should == 2
      li.max_quantity.should == 2
    end
  end
end
