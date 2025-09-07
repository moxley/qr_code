defmodule SvgTest do
  @moduledoc false

  use ExUnit.Case
  alias QRCode
  alias QRCode.Render.SvgSettings

  @text "HELLO WORLD"
  @dst_to_file "/tmp/hello.svg"
  @rgx_svg_attrs ~r/[xmlns=http:\/\/www.w3.org\/2000\/svg | xlink=http:\/\/www.w3.org\/1999\/xlink]/
  @rgx_qr_color ~r/fill="#11AA88"/
  @rgx_bg_opacity ~r/fill-opacity=/
  @rgx_embedded_image ~r/href="data:image\/png;/

  describe "Svg" do
    setup do
      @text
      |> QRCode.create()
      |> QRCode.render(:svg, %SvgSettings{structure: :readable})
      |> QRCode.save(@dst_to_file)

      on_exit(fn ->
        :ok = File.rm(@dst_to_file)
      end)
    end

    test "render should fail with error" do
      rv =
        Result.error("Error")
        |> QRCode.render()

      assert rv == {:error, "Error"}
    end

    test "should save qr code to svg file" do
      assert File.exists?(@dst_to_file)
    end

    test "should create svg from qr matrix" do
      {:ok, expected} =
        @text
        |> QRCode.create()
        |> QRCode.render(:svg, %SvgSettings{structure: :readable})

      rv =
        @dst_to_file
        |> File.read!()

      assert expected == rv
    end

    test "should encode svg binary to base64" do
      {:ok, expected} =
        @text
        |> QRCode.create()
        |> QRCode.render()

      {:ok, rv} =
        @text
        |> QRCode.create()
        |> QRCode.render()
        |> QRCode.to_base64()
        |> Result.and_then(&Base.decode64/1)

      assert expected == rv
    end

    test "file should contain xmlns and xlink attributes" do
      rv =
        @dst_to_file
        |> File.stream!()
        |> Stream.take(2)
        |> Enum.at(0)

      assert Regex.match?(@rgx_svg_attrs, rv)
    end

    test "file should not contain background opacity" do
      rv =
        @dst_to_file
        |> File.stream!()
        |> Stream.take(2)
        |> Enum.at(1)

      refute Regex.match?(@rgx_bg_opacity, rv)
    end

    test "file should contain background opacity" do
      @text
      |> QRCode.create()
      |> QRCode.render(
        :svg,
        %SvgSettings{background_opacity: 0, structure: :readable}
      )
      |> QRCode.save(@dst_to_file)

      rv =
        @dst_to_file
        |> File.stream!()
        |> Stream.take(2)
        |> Enum.at(1)

      assert Regex.match?(@rgx_bg_opacity, rv)
    end

    test "file should contain embedded image" do
      png_image = "/tmp/embedded_img.png"

      on_exit(fn ->
        :ok = File.rm(png_image)
      end)

      @text
      |> QRCode.create()
      |> QRCode.render(:png)
      |> QRCode.save(png_image)

      settings = %SvgSettings{
        image: {png_image, 100},
        structure: :readable
      }

      @text
      |> QRCode.create()
      |> QRCode.render(:svg, settings)
      |> QRCode.save(@dst_to_file)

      rv =
        @dst_to_file
        |> File.stream!()
        |> Stream.take(-2)
        |> Enum.at(-2)

      assert Regex.match?(@rgx_embedded_image, rv)
    end

    test "file should contain different qr code color than black" do
      @text
      |> QRCode.create()
      |> QRCode.render(
        :svg,
        %SvgSettings{qrcode_color: {17, 170, 136}, structure: :readable}
      )
      |> QRCode.save(@dst_to_file)

      rv =
        @dst_to_file
        |> File.stream!()
        |> Stream.take(3)
        |> Enum.at(-1)

      assert Regex.match?(@rgx_qr_color, rv)
    end

    test "render svg with no margin when quiet_zone is 0" do
      {:ok, qr} = QRCode.create("A")  # Simple QR code for predictable size

      # Get the original matrix size
      {rows, cols} = MatrixReloaded.Matrix.size(qr.matrix)

      # Render with quiet_zone: 0 and scale: 10
      {:ok, svg_content} =
        QRCode.render({:ok, qr}, :svg, %SvgSettings{quiet_zone: 0, scale: 10, structure: :readable})

      # The SVG dimensions should match exactly the matrix size * scale
      expected_size = rows * 10
      assert svg_content =~ ~r/width="#{expected_size}"/
      assert svg_content =~ ~r/height="#{expected_size}"/

      # There should be rectangles starting at x="0" and y="0" (no margin)
      assert svg_content =~ ~r/x="0"/
      assert svg_content =~ ~r/y="0"/

      # Verify that MatrixHelper.surround_matrix works with quiet_zone: 0
      matrix_with_no_quiet = QRCode.MatrixHelper.surround_matrix(qr.matrix, 0, 0)
      assert MatrixReloaded.Matrix.size(matrix_with_no_quiet) == {rows, cols}

      # Compare with quiet_zone: 1 to ensure the difference is clear
      {:ok, svg_with_margin} =
        QRCode.render({:ok, qr}, :svg, %SvgSettings{quiet_zone: 1, scale: 10, structure: :readable})

      # With quiet_zone: 1, dimensions should be 2 units larger (1 unit margin on each side)
      expected_size_with_margin = (rows + 2) * 10
      assert svg_with_margin =~ ~r/width="#{expected_size_with_margin}"/
      assert svg_with_margin =~ ~r/height="#{expected_size_with_margin}"/
    end

    test "render svg with 1-unit margin when quiet_zone is 1" do
      {:ok, qr} = QRCode.create("A")  # Simple QR code for predictable size

      # Get the original matrix size
      {rows, cols} = MatrixReloaded.Matrix.size(qr.matrix)

      # Render with quiet_zone: 1 and scale: 10
      {:ok, svg_content} =
        QRCode.render({:ok, qr}, :svg, %SvgSettings{quiet_zone: 1, scale: 10, structure: :readable})

      # The SVG dimensions should be matrix size + 2 units (1 on each side) * scale
      expected_size = (rows + 2) * 10
      assert svg_content =~ ~r/width="#{expected_size}"/
      assert svg_content =~ ~r/height="#{expected_size}"/

      # With 1-unit margin, the first QR rectangles should start at x="10" and y="10" (not x="0")
      # because there's a 1-unit (10-pixel) margin on each side
      assert svg_content =~ ~r/x="10"/
      assert svg_content =~ ~r/y="10"/

      # Verify that MatrixHelper.surround_matrix works with quiet_zone: 1
      matrix_with_quiet_1 = QRCode.MatrixHelper.surround_matrix(qr.matrix, 1, 0)
      assert MatrixReloaded.Matrix.size(matrix_with_quiet_1) == {rows + 2, cols + 2}

      # The surrounded matrix should have white (0) borders
      # Check first row is all zeros (white margin)
      first_row = List.first(matrix_with_quiet_1)
      assert Enum.all?(first_row, &(&1 == 0))

      # Check last row is all zeros (white margin)
      last_row = List.last(matrix_with_quiet_1)
      assert Enum.all?(last_row, &(&1 == 0))

      # Check first column is all zeros (white margin)
      first_col = Enum.map(matrix_with_quiet_1, &List.first/1)
      assert Enum.all?(first_col, &(&1 == 0))

      # Check last column is all zeros (white margin)
      last_col = Enum.map(matrix_with_quiet_1, &List.last/1)
      assert Enum.all?(last_col, &(&1 == 0))
    end
  end
end
