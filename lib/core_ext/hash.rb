class Hash
  def slice(*attributes)
    attributes.inject({}) do |sliced, attribute|
      sliced[attribute] = self[attribute]
      sliced
    end
  end
end