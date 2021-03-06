require './tes.rb'
# Constants - Do not change
POLICIES = [:random, :roundrobin, :lcq]
POLICIES2 = [:random, :aslcq, :lcsflcq]

# Calculates the average of all the numbers in the array
def average(arr)
  arr.reduce(:+).to_f / arr.size
end

# default no correlation (global values)
$a = 0.5;
$b = 0.5;
$tesON = false
$filename = ""

puts "TES on? (y/n)? (default = n)"

case gets.chomp
when "y"
  puts "Which correlation would you like?"
  puts "h = High correlation (a = b = 0.1)"
  puts "l = Low correlation (a = b = 0.4)"
  puts "n = No correlation (a = b = 0.5)"

  case gets.chomp
  when "h"
    $a = 0.1
    $b = 0.1
    $filename = "tes-high-correlation-"
  when "l"
    $a = 0.4
    $b = 0.4
    $filename = "tes-low-correlation-"
  else
    $filename = "tes-no-correlation-"
  end

  $tesON = true

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
    if $tesON == true
      for i in (0...@numQueues)
        queue = @queues[i]
        queue.generateTESArrival(@time)
      end
    else
      for i in (0...@numQueues)
        queue = @queues[i]
        queue.generateArrival(@time)
      end
    end
  end

  def getStatistics
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

    {
      totalAverageQueueOccupancy: totalAverageQueueOccupancy,
      range: range,
      lowCI: lowCI,
      highCI: highCI
    }
  end

  def printStatistics
    results = getStatistics
    puts "\nResults for Policy = #{@policy}, p = #{@probabs}, and lambda = #{@lambdas}"
    puts "Average queue length over #{@maxReps} reps: #{results[:totalAverageQueueOccupancy]}"
    puts "Range = #{results[:range]}"
    puts "95% Confidence interval = (#{results[:lowCI]}, #{results[:highCI]})"
  end

  def writeStatistics(file, extras = [])
    results = getStatistics
    values = extras + [
      results[:totalAverageQueueOccupancy],
      results[:lowCI],
      results[:highCI]
    ]
    file.puts(values.join(","))
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
        connected_queues = @queues.select { |q| q.connected? }
        assignments.push([s, connected_queues.sample])
      end
    elsif policy == :aslcq
      # Each server gets allocated to longest queue thats connected to it.
      shuffled_servers.each do |s|
        connected_queues = @queues.select { |q| q.connected? }
        longest_connected_queue = connected_queues.sort_by(&:size).reverse[0]
        assignments.push([s, longest_connected_queue])
      end
    elsif policy == :lcsflcq
      serverConnectedQueues = []

      # Least Connected Server First/Longest Connected Queue (LCSF/LCQ)
      shuffled_servers.each do |s|
        connected_queues = @queues.select { |q| q.connected? }
        serverConnectedQueues.push([s, connected_queues])
      end

      # sorted is sorted based on ascending connected queue length
      sorted = serverConnectedQueues.sort_by do |item|
        item[1].size # Sort by number of connected queues
      end

      least_connected_server = sorted[0][0]
      longest_connected_queue = sorted[0][1].sort_by(&:size).reverse[0]

      assignments.push([least_connected_server, longest_connected_queue])

      sorted.delete_if do |item|
        item[0] == least_connected_server
      end

      sorted.each do |item|
        server = item[0]
        queue = item[1].sort_by(&:size).reverse[0]
        assignments.push([server, queue])
      end
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
    (0...@maxReps).each do |i|
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
          # Topology 2
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

      print "."

      collectRepStats()
      resetSimulation()
    end

    puts "done"
  end
end

# SimQueue represents a Queue for
# the purposes of this simulation.
class SimQueue

  def initialize(probability, lambda)
    @queue = Array.new
    @lambda = lambda
    @probConnected = probability
    @tesGenerator = Tes.new($a, $b)
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

  def generateTESArrival(t)
    if @tesGenerator.get_next() < @lambda
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

MAX_TIME = 50000
MAX_REPS = 20

puts 'Running your simulation. Please be patient...'


def top1_symmetric
  {1.0 => 0.02, 0.8 => 0.02, 0.2 => 0.014}.each do |p, lambda_step|
    POLICIES.each do |policy|
      file = File.open("results/topology1/symmetric/#{$filename}p#{p}-#{policy}.csv", 'w')
      lambdas = Array.new(10, lambda_step).map.with_index {|x, i| x * (i+1) }
      lambdas.each do |lambda|
        pn = Array.new(5, p)
        ln = Array.new(5, lambda)
        sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
        sim.runSimulation
        sim.writeStatistics(file, [lambda])
      end
    end
  end
end

def top1_asymmetric
  POLICIES.each do |policy|
    file = File.open("results/topology1/asymmetric/#{$filename}#{policy}.csv", 'w')
    base_lambdas = (1..10).collect { |n| 0.006 * n }
    base_lambdas.each do |base_lambda|
      pn = [1.0, 0.8, 0.6, 0.4, 0.2]
      ln = (1..5).collect { |n| base_lambda * n }
      sim = Simulation.new(MAX_TIME, MAX_REPS, 5, 1, policy, pn, ln)
      sim.runSimulation
      sim.writeStatistics(file, [base_lambda])
    end
  end
end

NUM_QUEUES = 5
NUM_SERVERS = 3

def top2
  POLICIES2.each do |policy|
    file = File.open("results/topology2/#{$filename}#{policy}.csv", 'w')
    base_lambdas = (1..10).collect { |n| 0.02 * n }
    base_lambdas.each do |base_lambda|
      pn = Array.new(5, 0.5)
      ln = (1..5).collect { |n| base_lambda * n }
      puts pn
      puts ln
      sim = Simulation.new(MAX_TIME, MAX_REPS, NUM_QUEUES, NUM_SERVERS, policy, pn, ln)
      sim.runSimulation
      sim.writeStatistics(file, [base_lambda])
    end
  end
end

puts "Run which simulation group?"
puts "a = topology 1 symmetric"
puts "b = topology 1 asymmetric"
puts "c = topology 2"

case gets.chomp
when "a"
  top1_symmetric
when "b"
  top1_asymmetric
when "c"
  top2
end
