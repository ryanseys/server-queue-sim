class Tes

public
  def initialize(a, b, n)
    @a = a
    @b = b
    @n = n
    @variates = Array.new
  end

  def get_variates
    seed unless @variates.any?
    @variates
  end

private
  def Vn1
    ((@a + @b)*rand()) - @b
  end

  def Un1
    if @variates.any?
      (@variates.last + Vn1()) % 1
    else
      rand
    end
  end

  def seed
    @n.times do
      @variates.push(Un1())
    end
  end
end
