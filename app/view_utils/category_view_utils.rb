module CategoryViewUtils

  module_function

  # Returns an array that contains the hierarchy of categories and listing shapes
  #
  # An xample of a returned tree:
  #
  # [
  #   {
  #     "label" => "item",
  #     "id" => id,
  #     "subcategories" => [
  #       {
  #         "label" => "tools",
  #         "id" => id,
  #         "listing_shapes" => [
  #           {
  #             "label" => "sell",
  #             "id" => id
  #           }
  #         ]
  #       }
  #     ]
  #   },
  #   {
  #     "label" => "services",
  #     "id" => "id"
  #   }
  # ]
  def category_tree(categories: categories, shapes: shapes, locale:, all_locales:, translation_cache:)
    categories.map { |c|
      {
        id: c[:id],
        label: pick_category_translation(c[:translations], locale, all_locales),
        listing_shapes: embed_shape(c[:listing_shape_ids], shapes, locale, all_locales, translation_cache),
        subcategories: category_tree(
          categories: c[:children],
          shapes: shapes,
          locale: locale,
          all_locales: all_locales,
          translation_cache: translation_cache
        )
      }
    }

  end

  # private

  def embed_shape(ids, shapes, locale, all_locales, translation_cache)
    shapes.select { |s|
      ids.include? s[:id]
    }.map { |s|
      {
        id: s[:id],
        label: TranslationServiceHelper.pick_translation(
          s[:name_tr_key],
          translation_cache,
          all_locales,
          locale
        )
      }
    }
  end

  def pick_category_translation(category_translations, locale, all_locales)
    prio = translation_preferences(locale, all_locales)
    category_translations.sort { |a, b|
      a_prio = prio[a[:locale]]
      b_prio = prio[b[:locale]]
      sort_num_or_nil(a_prio, b_prio)
    }.first[:name]
  end

  def translation_preferences(preferred, all)
    [preferred].concat(all).map(&:to_s)
      .uniq
      .each_with_index
      .map { |l, index| [l, index] }
      .to_h
  end

  def sort_num_or_nil(a, b)
    if a.nil?
      1
    elsif b.nil?
      -1
    else
      a <=> b
    end
  end
end
