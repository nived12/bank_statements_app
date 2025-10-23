# frozen_string_literal: true

##
# Savings::CreateService
# Creates a new saving
#
class Savings::CreateService < ApplicationService
  def initialize(saving_params)
    super()
    @saving_params = saving_params
  end

  def call
    @saving = Saving.new(@saving_params)

    if @saving.save
      success(@saving)
    else
      failure(@saving.errors)
    end
  end

  private

  attr_reader :saving_params
end
