# Constants to change
MAX_TIME = 10
MAX_REPETITIONS = 20
NUM_QUEUES = 5
NUM_SERVERS = 1
CASE = 1
SYMMETRIC = true
POLICY = :random

# SimQueue represents a Queue for
# the purposes of this simulation.
class SimQueue

  def initialize(lambda, probability)
    @queue = Array.new
    @connected = false
    @lambda = lambda
    @probability = probability
  end

  def connect
    @connected = true
  end

  def disconnect
    @connected = false
  end

  def connected?
    @connected
  end

  def enq(x)
    @queue.push(x)
  end

  def deq(x)
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

time = 0
@queues = []

policies = {
  :random => true,
  :roundrobin => true,
  :lcq => true
}

server = Server.new
numServiced = 0
probability = 1 # queue n is connected with probability pn i.e., E[Cn(t)] = pn.
lambda = 0.02

# Selects a queue based on the different policies possible
def selectQueue(policy)
  if policy == :random
    # Return queue with max length
    return @queues.select { |q| q.connected? }.max_by(&:size)
  elsif policy == :roundrobin
    puts 'Policy Round Robin not implemented.'
    raise
  elsif policy == :lcq
    puts 'Policy LCQ not implemented.'
    raise
  end
end

def generateArrivals(time)
  for i in (0..NUM_QUEUES)
    queue = @queues[i]
    queue.generateArrival(time)
  end
end

# Create N queues
for i in (0..NUM_QUEUES)
  @queues[i] = SimQueue.new(lambda, probability)
end

while time <= MAX_TIME
  # Check if policy exists
  if not policies.member?(POLICY)
    puts 'Invalid policy!'
    break
  end

  # Step 1. Select a queue given the policy set
  queue = selectQueue(POLICY)

  # Step 2. Server serves the head packet in the queue.
  if queue.nil?
    puts 'No queue could be selected.'
  else
    packet = queue.deq()
    server.process(packet)
    numServiced += 1
  end

  # Step 3. New packet arrivals are added to the queues.
  generateArrivals(time)

  # TODO. Lots to do.

  time += 1
end
