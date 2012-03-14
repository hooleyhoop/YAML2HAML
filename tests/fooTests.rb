require 'test/unit'

class BaseTest < Test::Unit::TestCase

  # Execute this before every test case.
  def setup
    # Do nothing.
  end

  # Execute this after every test case.
  def teardown
    # Do nothing.
  end
  
 def test_empty
    # Empty
  end

 def test_file_exists_pass
    # I can summon this to manually abort the test if I wanted to.
    # abort_test!
    # This tests for itself, which ought to pass.
    assert(test(?e,__FILE__),"** ERROR:  The file is missing")
  end
  
  def test_file_exists_fail
    assert(test(?e,"filename.ext"),"** ERROR:  The file is missing")
  end


end