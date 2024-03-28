class Installation::OnboardingController < ApplicationController
  before_action :ensure_installation_onboarding

  def index; end

  def create
    begin
      AccountBuilder.new(
        account_name: onboarding_params.dig(:user, :company),
        user_full_name: onboarding_params.dig(:user, :name),
        email: onboarding_params.dig(:user, :email),
        user_password: params.dig(:user, :password),
        super_admin: true,
        confirmed: true
      ).perform
    rescue StandardError => e
      redirect_to '/', flash: { error: e.message } and return
    end
    InstallationConfig.update_all(locked: false)
    pricing_plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')
    pricing_plan_quantity = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    pricing_plan.value = 'premium'
    pricing_plan_quantity.value = 999
    pricing_plan_quantity.save!
    pricing_plan.save!
    finish_onboarding
    redirect_to '/'
  end

  private

  def onboarding_params
    params.permit(:subscribe_to_updates, user: [:name, :company, :email])
  end

  def finish_onboarding
    ::Redis::Alfred.delete(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
    return if onboarding_params[:subscribe_to_updates].blank?

    ChatwootHub.register_instance(
      onboarding_params.dig(:user, :company),
      onboarding_params.dig(:user, :name),
      onboarding_params.dig(:user, :email)
    )
  end

  def ensure_installation_onboarding
    redirect_to '/' unless ::Redis::Alfred.get(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
  end
end
