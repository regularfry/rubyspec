require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../fixtures/classes', __FILE__)

ruby_version_is "1.9" do
  describe :io_copy_stream_to_file, :shared => true do
    it "copies the entire IO contents to the file" do
      IO.copy_stream(@object.from, @to_name)
      @to_name.should have_data(@content)
    end

    it "returns the number of bytes copied" do
      IO.copy_stream(@object.from, @to_name).should == @size
    end

    it "copies only length bytes when specified" do
      IO.copy_stream(@object.from, @to_name, 8).should == 8
      @to_name.should have_data("Line one")
    end

    it "copies only length bytes from the offset" do
      IO.copy_stream(@object.from, @to_name, 8, 4).should == 8
      @to_name.should have_data(" one\n\nLi")
    end

    it "calls #to_path to convert on object to a file name" do
      obj = mock("io_copy_stream_to")
      obj.should_receive(:to_path).and_return(@to_name)

      IO.copy_stream(@object.from, obj)
      @to_name.should have_data(@content)
    end

    it "raises a TypeError if #to_path does not return a String" do
      obj = mock("io_copy_stream_to")
      obj.should_receive(:to_path).and_return(1)

      lambda { IO.copy_stream(@object.from, obj) }.should raise_error(TypeError)
    end
  end

  describe :io_copy_stream_to_io, :shared => true do
    it "copies the entire IO contents to the IO" do
      IO.copy_stream(@object.from, @to_io)
      @to_name.should have_data(@content)
    end

    it "returns the number of bytes copied" do
      IO.copy_stream(@object.from, @to_io).should == @size
    end

    it "starts writing at the destination IO's current position" do
      @to_io.write("prelude ")
      IO.copy_stream(@object.from, @to_io)
      @to_name.should have_data("prelude " + @content)
    end

    it "leaves the destination IO position at the last write" do
      IO.copy_stream(@object.from, @to_io)
      @to_io.pos.should == @size
    end

    it "raises an IOError if the destination IO is not open for writing" do
      @to_io.close
      @to_io = File.open @to_name, "r"
      lambda { IO.copy_stream @object.from, @to_io }.should raise_error(IOError)
    end

    it "does not close the destination IO" do
      IO.copy_stream(@object.from, @to_io)
      @to_io.closed?.should be_false
    end

    it "copies only length bytes when specified" do
      IO.copy_stream(@object.from, @to_io, 8).should == 8
      @to_name.should have_data("Line one")
    end

    it "copies only length bytes from the offset" do
      IO.copy_stream(@object.from, @to_io, 8, 4).should == 8
      @to_name.should have_data(" one\n\nLi")
    end
  end

  describe "IO.copy_stream" do
    before :each do
      @from_name = fixture __FILE__, "copy_stream.txt"
      @to_name = tmp("io_copy_stream_io_name")

      @content = IO.read(@from_name)
      @size = @content.size
    end

    after :each do
      rm_r @to_name
    end

    describe "from an IO" do
      before :each do
        @from_io = File.open @from_name, "rb"
        IOSpecs::CopyStream.from = @from_io
      end

      after :each do
        @from_io.close
      end

      it "raises an IOError if the source IO is not open for reading" do
        @from_io.close
        @from_io = File.open @from_name, "a"
        lambda { IO.copy_stream @from_io, @to_name }.should raise_error(IOError)
      end

      it "does not close the source IO" do
        IO.copy_stream(@from_io, @to_name)
        @from_io.closed?.should be_false
      end

      it "does not change the IO offset when an offset is specified" do
        @from_io.pos = 10
        IO.copy_stream(@from_io, @to_name, 8, 4)
        @from_io.pos.should == 10
      end

      it "does change the IO offset when an offset is not specified" do
        @from_io.pos = 10
        IO.copy_stream(@from_io, @to_name)
        @from_io.pos.should == 42
      end

      describe "to a file name" do
        it_behaves_like :io_copy_stream_to_file, nil, IOSpecs::CopyStream
      end

      describe "to an IO" do
        before :each do
          @to_io = File.open @to_name, "wb"
        end

        after :each do
          @to_io.close
        end

        it_behaves_like :io_copy_stream_to_io, nil, IOSpecs::CopyStream
      end
    end

    describe "from a file name" do
      before :each do
        IOSpecs::CopyStream.from = @from_name
      end

      it "calls #to_path to convert on object to a file name" do
        obj = mock("io_copy_stream_from")
        obj.should_receive(:to_path).and_return(@from_name)

        IO.copy_stream(obj, @to_name)
        @to_name.should have_data(@content)
      end

      it "raises a TypeError if #to_path does not return a String" do
        obj = mock("io_copy_stream_from")
        obj.should_receive(:to_path).and_return(1)

        lambda { IO.copy_stream(obj, @to_name) }.should raise_error(TypeError)
      end

      describe "to a file name" do
        it_behaves_like :io_copy_stream_to_file, nil, IOSpecs::CopyStream
      end

      describe "to an IO" do
        before :each do
          @to_io = File.open @to_name, "wb"
        end

        after :each do
          @to_io.close
        end

        it_behaves_like :io_copy_stream_to_io, nil, IOSpecs::CopyStream
      end
    end
  end
end
