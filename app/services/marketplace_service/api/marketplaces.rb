module MarketplaceService::API

  module Marketplaces
    CommunityModel = ::Community

    RESERVED_DOMAINS = [
      "www",
      "home",
      "sharetribe",
      "login",
      "blog",
      "business",
      "catch",
      "webhooks",
      "dashboard",
      "dashboardtranslate",
      "translate",
      "community",
      "wiki",
      "mail",
      "secure",
      "host",
      "feed",
      "feeds",
      "app",
      "beta-site",
      "marketplace",
      "marketplaces",
      "masters",
      "marketplacemasters",
      "insights",
      "insight",
      "tips",
      "doc",
      "docs",
      "support",
      "legal",
      "org",
      "net",
      "web",
      "intra",
      "intranet",
      "internal",
      "webinar",
      "local",
      "proxy",
      "preproduction",
      "staging"
    ]

    module_function

    def create(params)
      p = Maybe(params)

      locale = p[:marketplace_language].or_else("en")
      marketplace_name = p[:marketplace_name].or_else("Trial Marketplace")

      community = CommunityModel.create(Helper.community_params(p, marketplace_name, locale))

      Helper.create_community_customization!(community, marketplace_name, locale)
      Helper.create_category!("Default", community, locale)
      shape = Helper.create_listing_shape!(community, p[:marketplace_type], :preauthorize)

      plan_level = p[:plan_level].or_else(CommunityPlan::FREE_PLAN)
      Helper.create_community_plan!(community, {plan_level: plan_level});

      return from_model(community)
    end

    # Create a Marketplace hash from Community model
    def from_model(community)
      hash = HashUtils.compact(
        EntityUtils.model_to_hash(community).merge({
            url: community.full_domain({with_protocol: true}),
            locales: community.locales
          }))
      # remove locale from settings as it's in the root level of the hash
      hash[:settings].delete("locales")
      return MarketplaceService::API::DataTypes::create_marketplace(hash)
    end

    module Helper

      module_function

      def community_params(params, marketplace_name, locale)
        ident = available_ident_based_on(marketplace_name)
        {
          consent: "SHARETRIBE1.0",
          ident: ident,
          settings: {"locales" => [locale]},
          available_currencies: available_currencies_based_on(params[:marketplace_country].or_else("us")),
          country: params[:marketplace_country].upcase.or_else(nil)
        }
      end

      def customization_params(marketplace_name, locale)
        {
          name: marketplace_name,
          locale: locale,
          how_to_use_page_content: how_to_use_page_default_content(locale, marketplace_name)
        }
      end

      def create_listing_shape!(community, marketplace_type, process)
        listing_shape_template = select_listing_shape_template(marketplace_type)
        enable_shipping = marketplace_type.or_else("product") == "product"
        TransactionTypeCreator.create(community, listing_shape_template, process, enable_shipping)
      end

      def create_community_customization!(community, marketplace_name, locale)
        community.community_customizations.create(customization_params(marketplace_name, locale))
      end

      def create_community_plan!(community, options={})
        CommunityPlan.create({
          community_id: community.id,
          plan_level:   Maybe(options[:plan_level]).or_else(0),
          expires_at:   Maybe(options[:expires_at]).or_else(DateTime.now.change({ hour: 9, min: 0, sec: 0 }) + 31.days)
        })
      end

      def select_listing_shape_template(type)
       case type.or_else("product")
        when "rental"
          "Rent"
        when "service"
          "Service"
        else # also "product" goes to this default
          "Sell"
        end
      end

      def how_to_use_page_default_content(locale, marketplace_name)
        "<h1>#{I18n.t("infos.how_to_use.default_title", locale: locale)}</h1><div>#{I18n.t("infos.how_to_use.default_content", locale: locale, :marketplace_name => marketplace_name)}</div>"
      end

      def available_ident_based_on(initial_ident)

        if initial_ident.blank?
          initial_ident = "trial_site"
        end

        current_ident = initial_ident.to_url
        current_ident = current_ident[0..29] #truncate to 30 chars or less

        # use basedomain as basis on new variations if current domain is not available
        base_ident = current_ident

        i = 1
        while CommunityModel.exists?(ident: current_ident) || RESERVED_DOMAINS.include?(current_ident) do
          current_ident = "#{base_ident}#{i}"
          i += 1
        end

        return current_ident
      end

      def available_currencies_based_on(country_code)
        Maybe(MarketplaceService::AvailableCurrencies::COUNTRY_CURRENCIES[country_code.upcase]).or_else("USD")
      end

      def create_category!(category_name, community, locale)
        translation = CategoryTranslation.new(:locale => locale, :name => category_name)
        community.categories.create!(:url => category_name.downcase, translations: [translation])
      end
    end
  end
end
