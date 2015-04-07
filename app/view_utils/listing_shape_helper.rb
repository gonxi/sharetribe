
module ListingShapeHelper

  module_function

  # deprecated
  #
  # This method is deprecated, but it's still in use in Atom API
  def shape_direction_map(shapes, processes)
    ArrayUtils.inner_join(shapes, processes) { |shape, process|
      shape[:transaction_process_id] == process[:id]
    }.map { |(shape, process)|
      [shape[:id], process_to_direction(process)]
    }.to_h
  end

  def process_to_direction(process)
    process[:author_is_seller] ? "offer" : "request"
  end
end
