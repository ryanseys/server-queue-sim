# Constants - Do not change
POLICIES = [:random, :roundrobin, :lcq]
POLICIES2 = [:random, :aslcq]

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

  def assignServersToQueues(policy)
    assignments = []

    shuffled_servers = @servers.shuffle
    if policy == :random
      # Each server gets allocated to a random connected queue
      shuffled_servers.each do |s|
        connected_queues = (@queues.select { |q| q.connected? })
        assignments.push([s, connected_queues.sample])
      end
    elsif policy == :aslcq
      # Each server gets allocated to longest queue thats connected to it.
      shuffled_servers.each do |s|
        connected_queues = (@queues.select { |q| q.connected? })
        longest_connected_queue = connected_queues.sort_by(&:size).reverse[0]
        assignments.push([s, longest_connected_queue])
      end
    elsif policy == :lcsflcq
      # Least Connected Server First/Longest Connected Queue (LCSF/LCQ)

      # TODO: Do this policy.
    end

    assignments
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
        # Topology 1
        if @servers.size == 1
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
        else
          # TODO: Topology 2
          # Step 1. Assign each server to a queue.
          assignments = assignServersToQueues(@policy)

          # Step 2. Servers serve the head packet of every queue.
          assignments.each do |assignment|
            server = assignment[0]
            queue = assignment[1]

            if queue.nil?
              # Nothing happens.
            else
              packet = queue.deq()
              server.process(packet)
            end
          end
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
  def process(packet)
    # We don't really need to do anything here with the packet.
  end
end

# Run your simulations here

MAX_TIME = 100
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

NUM_QUEUES = 5
NUM_SERVERS = 3

POLICIES2.each do |policy|
  # TODO: Topology 2
  lambdas = Array.new(10, 0.02).map.with_index {|x, i| x * (i+1) }
  lambdas.each do |lambda|
    pn = Array.new(5, 0.5)
    ln = Array.new(5, lambda).map.with_index {|x, i| x * (i+1) }
    sim = Simulation.new(MAX_TIME, MAX_REPS, NUM_QUEUES, NUM_SERVERS, policy, pn, ln)
    sim.runSimulation
    sim.printStatistics
  end
end
