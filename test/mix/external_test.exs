Code.require_file "../test_helper", __FILE__

defmodule ExternalTest do
  use ExUnit.Case
  import Mix.External

  test :take_all do
    assert "foo\n" == take_all(run_cmd("echo", ["foo"]))
  end

  test :lists do
    assert "foo\n" == take_all(run_cmd('echo', ['foo']))
  end
end
