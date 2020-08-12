# frozen_string_literal: true

require 'spec_helper'

describe DfcProvider::Api::EnterprisesController, type: :controller do
  render_views

  let!(:user) { create(:user) }
  let!(:enterprise) { create(:distributor_enterprise, owner: user) }
  let!(:product) { create(:simple_product, supplier: enterprise ) }

  describe('.show') do
    context 'with authorization token' do
      before do
        request.headers['Authorization'] = 'Bearer 123456.abcdef.123456'
      end

      context 'with an authenticated user' do
        before do
          allow_any_instance_of(DfcProvider::AuthorizationControl)
            .to receive(:process)
            .and_return(user)
        end

        context 'with an enterprise' do
          context 'given with an id' do
            context 'related to the user' do
              before { api_get :show, id: 'default' }

              it 'is successful' do
                expect(response.status).to eq 200
              end

              it 'renders the required content' do
                expect(response.body)
                  .to include(product.name)
                expect(response.body)
                  .to include(product.sku)
                expect(response.body)
                  .to include("offers/#{product.variants.first.id}")
              end
            end
          end
        end
      end
    end
  end
end
