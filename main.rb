# Constants - Do not change
POLICIES = [:random, :roundrobin, :lcq]
POLICIES2 = [:random, :aslcq, :lcsflcq]

# Calculates the average of all the numbers in the array
def average(arr)
  arr.reduce(:+).to_f / arr.size
end

class Simulation
  def initialize(maxTime, maxReps, numQueues, numServers, policy, pn, ln)
    @maxTime = maxTime
    @maxReps = maxReps
    @numQueues = numQueues
    @numServers = numServers
    @policy = policy
    @time = 0
    @queues = []
    @servers = []
    @probabs = pn
    @lambdas = ln

    @roundRobinNextIndex = 0

    # Create N queues
    for i in (0...@numQueues)
      @queues[i] = SimQueue.new(@probabs[i], @lambdas[i])
    end

    for i in (0...@numServers)
      @servers[i] = Server.new
    end

    @stats = {
      :numServiced => 0,
      :averageQueueLengths => [],
      :averagePerRep => []
    }
  end

  def generateArrivals()
    for i in (0...@numQueues)
      queue = @queues[i]
      queue.generateArrival(@time)
    end
  end

  def printStatistics
    queueOccupancies = @stats[:averagePerRep]
    totalAverageQueueOccupancy = average(queueOccupancies)

    # 95% Confidence Interval
    sum = 0

    queueOccupancies.each do |occ|
      sum += ((occ - totalAverageQueueOccupancy) ** 2)
    end

    s_squared = sum/(@maxReps-1);
    s = Math.sqrt(s_squared);

    t = 2.093; # 95% confidence interval t-statistic for N = 20
    range = t * s / Math.sqrt(@maxReps-1);
    lowCI = totalAverageQueueOccupancy - range;
    highCI = totalAverageQueueOccupancy + range;

    puts "\nResults for Policy = #{@policy}, p = #{@probabs}, and λ = #{@lambdas}"
    puts "Average queue length over #{@maxReps} reps: #{totalAverageQueueOccupancy}"
    puts "Range = #{range}"
    puts "95% Confidence interval = (#{lowCI}, #{highCI})"
  end

  # Selects a queue based on the different policies possible
  def selectQueue(policy)
    if policy == :random
      # Return random connected queue
      return (@queues.select { |q| q.connected? }).sample
    elsif policy == :roundrobin
      queue = @queues[@roundRobinNextIndex]
      @roundRobinNextIndex = (@roundRobinNextIndex + 1) % @numQueues
      if queue.empty? or not queue.connected?
        nil
      else
        queue
      end
    elsif policy == :lcq
      # Return connected queue with max length
      return (@queues.select { |q| q.connected? }).max_by(&:size)
    end
  end

  def collectStatistics
    queueLengths = @queues.map { |q| q.size }
    averageLength = average(queueLengths)
    @stats[:averageQueueLengths].push(averageLength)
  end

  def collectRepStats
    avgs = @stats[:averageQueueLengths]
    @stats[:averagePerRep].push(average(avgs))
  end

  def resetSimulation
    @time = 0
    @stats[:numServiced] = 0
    @stats[:averageQueueLengths] = []
  end

  def runSimulation
    for i in (0...@maxReps)
      while @time <= @maxTime
        # Step 1. Select a queue given the policy set
        queue = selectQueue(@policy)

        # Step 2. Server serves the head packet in the queue.
        if queue.nil?
          # Nothing happens. Wasted time slot.
        else
          packet = queue.deq()
          @servers[0].process(packet) # Use only first server
          @stats[:numServiced] += 1
        end

        # Step 3. New packet arrivals are added to the queues.
        generateArrivals()

        collectStatistics()

        @time += 1
      end

      collectRepStats()
      resetSimulation()
    end
  end
end

# SimQueue represents a Queue for
# the purposes of this simulation.
class SimQueue

  def initialize(probability, lambda)
    @queue = Array.new
    @lambda = lambda
    @probConnected = probability
  end

  def connected?
    rand() < @probConnected
  end

  def size
    @queue.size
  end

  def enq(x)
    @queue.push(x)
  end

  def deq()
    @queue.shift()
  end

  def empty?
    @queue.empty?
  end

  def generateArrival(t)
    if rand() < @lambda
      @queue.push(t)
    end
  end
end

class Server
  def initialize
    @busy = false
    @packet = nil
  end

  def busy?
    @busy
  end

  def process(packet)
    if not packet.nil?
      @busy = true
      @packet = packet
    end
  end

  def endProcess
    @busy = false
    @packet = nil
  end
end

# Run your simulations here

MAX_TIME = 10000
MAX_REPS = 20

puts 'Running your simulation. Please be patient...'

# Topology 1 - Symmetric (All p are equal)

POLICIES.each do |policy|

  # p = 1, λ = 0.02
  pn = Array.new(5, 1.0)
  ln = Array.new(5, 0.02)
  sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
  sim.runSimulation
  sim.printStatistics

  # p = 1, λ = 0.02 × i, i = 1, 2, ...
  lambdas = Array.new(10, 0.02).map.with_index {|x, i| x * (i+1) }
  lambdas.each do |lambda|
    pn = Array.new(5, 1.0)
    ln = Array.new(5, lambda)
    sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
    sim.runSimulation
    sim.printStatistics
  end

  # p = 0.8, λ = 0.02 × i, i = 1, 2, ...
  lambdas = Array.new(10, 0.02).map.with_index {|x, i| x * (i+1) }
  lambdas.each do |lambda|
    pn = Array.new(5, 0.8)
    ln = Array.new(5, lambda)
    sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
    sim.runSimulation
    sim.printStatistics
  end

  # p = 0.2, λ = 0.014 × i, i = 1, 2, ...
  lambdas = Array.new(10, 0.014).map.with_index {|x, i| x * (i+1) }
  lambdas.each do |lambda|
    pn = Array.new(5, 0.2)
    ln = Array.new(5, lambda)
    sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
    sim.runSimulation
    sim.printStatistics
  end

  # Topology 1 - Asymmetric (p are different)

  # p1 = 1, p2 = 0.8, p3 = 0.6, p4 = 0.4 and p5 = 0.2
  # λ = 0.006 × i, i = 1, 2, ...
  lambdas = Array.new(10, 0.006).map.with_index {|x, i| x * (i+1) }
  lambdas.each do |lambda|
    pn = Array.new(5, 0.2).map.with_index {|x, i| x * (5-i) }
    ln = Array.new(5, lambda)
    sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
    sim.runSimulation
    sim.printStatistics
  end
end

POLICIES2.each do |policy|
  # TODO: Topology 2
end
