class Tes

public
  def initialize(a, b)
    @a = a
    @b = b
    @prev = nil
  end

  def get_next()
    Un1()
  end

private
  def Vn1
    ((@a + @b)*rand()) - @b
  end

  def Un1()
    if not @prev.nil?
      @prev = (@prev + Vn1()) % 1
      @prev
    else
      @prev = rand
      @prev
    end
  end
end
