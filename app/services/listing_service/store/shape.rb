module ListingService::Store::Shape

  ListingUnitModel = ::ListingUnit

  NewShape = EntityUtils.define_builder(
    [:community_id, :fixnum, :mandatory],
    [:price_enabled, :bool, :mandatory],
    [:name_tr_key, :string, :mandatory],
    [:action_button_tr_key, :string, :mandatory],
    [:transaction_process_id, :fixnum, :mandatory],
    [:shipping_enabled, :bool, :mandatory],
    [:units, :array, default: []], # Mandatory only if price_enabled
    [:price_quantity_placeholder, one_of: [nil, :mass, :time, :long_time]], # TODO TEMP
    [:sort_priority, :fixnum, default: 0],
    [:basename, :string, :mandatory]
  )

  Shape = EntityUtils.define_builder(
    [:id, :fixnum, :mandatory],
    [:community_id, :fixnum, :mandatory],
    [:price_enabled, :bool, :mandatory],
    [:name_tr_key, :string, :mandatory],
    [:action_button_tr_key, :string, :mandatory],
    [:transaction_process_id, :fixnum, :mandatory],
    [:units, :array, :mandatory],
    [:shipping_enabled, :bool, :mandatory],
    [:name, :string, :mandatory],
    [:sort_priority, :fixnum, default: 0],
    [:price_quantity_placeholder, :to_symbol, one_of: [nil, :mass, :time, :long_time]] # TODO TEMP
  )

  UpdateShape = EntityUtils.define_builder(
    [:price_enabled, :bool],
    [:name_tr_key, :string],
    [:action_button_tr_key, :string],
    [:transaction_process_id, :fixnum],
    [:units, :array],
    [:shipping_enabled, :bool],
    [:sort_priority, :fixnum]
  )

  Unit = EntityUtils.define_builder(
    [:type, :to_symbol, one_of: [:piece, :hour, :day, :night, :week, :month, :custom]],
    [:translation_key, :optional] # Mandatory if custom
  )

  module_function

  def get(community_id:, listing_shape_id: nil)
    shape_model = find_shape_model(
      community_id: community_id,
      listing_shape_id: listing_shape_id)

    from_model(shape_model)
  end

  def get_all(community_id:)
    shape_models = find_shape_models(community_id: community_id)

    shape_models.map { |shape_model|
      from_model(shape_model)
    }
  end

  def create(community_id:, opts:)
    shape = NewShape.call(opts.merge(community_id: community_id))

    units = shape[:units].map { |unit| Unit.call(unit) }

    name = uniq_name(shape[:basename], shape[:community_id])
    shape_with_name = shape.except(:basename).merge(name: name)

    ActiveRecord::Base.transaction do

      # Save to ListingShape model
      shape_model = ListingShape.create!(shape_with_name.except(:units))

      # Save units
      units.each { |unit|
        shape_model.listing_units.create!(to_unit_model_attributes(unit))
      }

      from_model(shape_model)
    end
  end

  def update(community_id:, listing_shape_id: nil, opts:)
    shape_model = find_shape_model(
      community_id: community_id,
      listing_shape_id: listing_shape_id)

    return nil if shape_model.nil?

    update_shape = UpdateShape.call(opts.merge(community_id: community_id))

    skip_units = update_shape[:units].nil?
    units = update_shape[:units].map { |unit| Unit.call(unit) } unless skip_units

    ActiveRecord::Base.transaction do
      unless skip_units
        shape_model.listing_units.destroy_all
        units.each { |unit| shape_model.listing_units.build(to_unit_model_attributes(unit)) }
      end

      # Save to ListingShape model
      shape_model.update_attributes!(HashUtils.compact(update_shape).except(:units))
    end

    from_model(shape_model)
  end

  # private

  def from_model(shape_model)
    Maybe(shape_model).map { |m|
      hash = EntityUtils.model_to_hash(m)

      hash[:units] = shape_model.listing_units.map { |unit_model|
        Unit.call(from_unit_model_attributes(EntityUtils.model_to_hash(unit_model)))
      }

      Shape.call(hash)
    }.or_else(nil)
  end

  def to_unit_model_attributes(hash)
    HashUtils.rename_keys(
      {
        type: :unit_type
      }, hash)
  end

  def from_unit_model_attributes(hash)
    HashUtils.rename_keys(
      {
        unit_type: :type
      }, hash)
  end

  def find_shape_model(community_id:, listing_shape_id:)
    find_shape_models(community_id: community_id).where(id: listing_shape_id).first
  end

  def find_shape_models(community_id:)
    ListingShape.where(community_id: community_id).order(:sort_priority)
  end

  def uniq_name(name_source, community_id)
    blacklist = ['new', 'all']
    current_name = name_source.to_url
    base_name = current_name

    shapes = find_shape_models(community_id: community_id)

    i = 1
    while blacklist.include?(current_name) || shapes.find { |s| s[:name] == current_name }.present? do
      current_name = "#{base_name}#{i}"
      i += 1
    end
    current_name

  end


end
