# Constants - Do not change
POLICIES = {
  :random => true,
  :roundrobin => true,
  :lcq => true
}

# Calculates the average of all the numbers in the array
def average(arr)
  arr.reduce(:+).to_f / arr.size
end

class SimulationTopologyOne
  def initialize(maxTime, maxReps, numQueues, numServers, policy, isSymmetric)
    @maxTime = maxTime
    @maxReps = maxReps
    @numQueues = numQueues
    @numServers = numServers
    @isSymmetric = isSymmetric
    @policy = policy

    @time = 0
    @queues = []
    @servers = []

    lambda = 0.02
    probability = 1

    # Create N queues
    for i in (0..@numQueues)
      @queues[i] = SimQueue.new(lambda, probability)
    end

    for i in (0..@numServers)
      @servers[i] = Server.new
    end

    @stats = {
      :numServiced => 0,
      :averageQueueLengths => []
    }
  end

  def generateArrivals()
    for i in (0..@numQueues)
      queue = @queues[i]
      queue.generateArrival(@time)
    end
  end

  def printStatistics
    puts "Average queue length: #{average(@stats[:averageQueueLengths])}"
  end

  # Selects a queue based on the different policies possible
  def selectQueue(policy)
    if policy == :random
      # Return queue with max length
      return (@queues.select { |q| q.connected? }).max_by(&:size)
    elsif policy == :roundrobin
      puts 'Policy Round Robin not implemented.'
      raise
    elsif policy == :lcq
      puts 'Policy LCQ not implemented.'
      raise
    end
  end

  def collectStatistics
    queueLengths = @queues.map { |q| q.size }
    averageLength = average(queueLengths)
    @stats[:averageQueueLengths].push(averageLength)
  end

  def runSimulation
    while @time <= @maxTime
      # Check if policy exists
      if not POLICIES.member?(@policy)
        puts 'Invalid policy!'
        break
      end

      # Step 1. Select a queue given the policy set
      queue = selectQueue(@policy)

      # Step 2. Server serves the head packet in the queue.
      if queue.nil?
        # puts 'No queue could be selected.'
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
  end
end

# SimQueue represents a Queue for
# the purposes of this simulation.
class SimQueue

  def initialize(lambda, probability)
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

sim1 = SimulationTopologyOne.new(1000, 20, 5, 1, :random, true)
sim1.runSimulation
sim1.printStatistics
