require File.expand_path('../../../spec_helper', __FILE__)

describe "IO.select" do
  before :each do
    @rd, @wr = IO.pipe
  end

  after :each do
    @rd.close unless @rd.closed?
    @wr.close unless @wr.closed?
  end

  it "blocks for duration of timeout if there are no objects ready for I/O" do
    timeout = 0.5
    start = Time.now
    IO.select [@rd], nil, nil, timeout
    (Time.now - start).should be_close(timeout, 2.0)
  end

  it "returns immediately all objects that are ready for I/O when timeout is 0" do
    @wr.write("be ready")
    result = IO.select [@rd], [@wr], nil, 0
    result.should == [[@rd], [@wr], []]
  end

  it "returns nil after timeout if there are no objects ready for I/O" do
    result = IO.select [@rd], nil, nil, 0
    result.should == nil
  end

  it "returns supplied objects when they are ready for I/O" do
    t = Thread.new { sleep 0.5; @wr.write "be ready" }
    t.abort_on_exception = true
    result = IO.select [@rd], nil, nil, nil
    result.should == [[@rd], [], []]
    t.join
  end

  it "leaves out IO objects for which there is no I/O ready" do
    @wr.write "be ready"
    # Order matters here. We want to see that @wr doesn't expand the size
    # of the returned array, so it must be 1st.
    result = IO.select [@wr, @rd], nil, nil, nil
    result.should == [[@rd], [], []]
  end

  it "returns supplied objects correctly even when monitoring the same object in different arrays" do
    filename = tmp("IO_select_pipe_file") + $$.to_s
    io = File.open(filename, 'w+')
    result = IO.select [io], [io], nil, 0
    result.should == [[io], [io], []]
    io.close
    rm_r filename
  end

  it "invokes to_io on supplied objects that are not IO and returns the supplied objects" do
    # make some data available
    @wr.write("foobar")

    obj = mock("read_io")
    obj.should_receive(:to_io).at_least(1).and_return(@rd)
    IO.select([obj]).should == [[obj], [], []]

    obj = mock("write_io")
    obj.should_receive(:to_io).at_least(1).and_return(@wr)
    IO.select(nil, [obj]).should == [[], [obj], []]
  end

  it "raises TypeError if supplied objects are not IO" do
    lambda { IO.select([Object.new]) }.should raise_error(TypeError)
    lambda { IO.select(nil, [Object.new]) }.should raise_error(TypeError)

    obj = mock("io")
    obj.should_receive(:to_io).any_number_of_times.and_return(nil)

    lambda { IO.select([obj]) }.should raise_error(TypeError)
    lambda { IO.select(nil, [obj]) }.should raise_error(TypeError)
  end

  it "raises TypeError if the specified timeout value is not Numeric" do
    lambda { IO.select([@rd], nil, nil, Object.new) }.should raise_error(TypeError)
  end

  it "raises TypeError if the first three arguments are not Arrays" do
    lambda { IO.select(Object.new)}.should raise_error(TypeError)
    lambda { IO.select(nil, Object.new)}.should raise_error(TypeError)
    lambda { IO.select(nil, nil, Object.new)}.should raise_error(TypeError)
  end

  it "sleeps the specified timeout if all streams are nil" do
    start = Time.now
    IO.select(nil, nil, nil, 0.1)
    (Time.now - start).should >= 0.1
  end

  it "does not accept negative timeouts" do
    lambda { IO.select(nil, nil, nil, -5)}.should raise_error(ArgumentError)
  end
  
  it "sets Thread.status to 'sleep'" do
    finished = false
    t = Thread.new do
      IO.select(nil, nil, nil, 0.25)
      finished=true
    end
    sleep(0.1)
    finished.should == false
    t.status.should == "sleep"
    t.kill
    t.join
  end


  it "sleeps given a nil timeout" do
    read = nil
    wokeup = false
    t = Thread.new do
      IO.select([@rd], nil, nil, nil)
      wokeup = true
      # Don't bother checking that it's actually returned from the select,
      # that's caught by another spec
      read = @rd.read(1)
    end

    sleep(0.1)
    wokeup.should == false

    @wr.write("a")
    # Sleep rather than join here so that if the select doesn't wake up
    # we don't hang the process
    sleep(0.1)

    read.should == "a"
    
    t.kill
    t.join
  end


end
