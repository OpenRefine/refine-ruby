gem 'minitest'
require 'minitest/autorun'
require_relative '../lib/refine.rb'


describe Refine do

  before do
    @refine_project = Refine.new({ "project_name" => 'date_cleanup', "file_name" => './test/dates.txt' })
  end

  it "finding project through project id" do
    new_refine_project = Refine.new({"project_name" => 'date_cleanup', "file_name" => './test/dates.txt'})

    finding_new_refine_project_using_id = Refine.new("project_id"=> new_refine_project.project_id)

    assert_equal new_refine_project.project_name, finding_new_refine_project_using_id.project_name
  end

	it "refine_initializer_has_instance_variable_project_name" do
		assert_equal 'date_cleanup', @refine_project.project_name
	end

  it "refine_initializer_has_instance_variable_project_id" do
    assert @refine_project.project_id.match(/^[0-9]+$/)
  end

  it "get_all_project_metadata" do
    assert Refine.get_all_project_metadata.instance_of? Hash
  end

  it "apply_operations" do
    assert @refine_project.apply_operations( './test/operations.json' )
  end

  it "call" do
     assert @refine_project.call( 'apply-operations', 'operations' => File.read( './test/operations.json' ) )
  end

  describe "deep linking into a facet state" do

    it "creates working url for custom expressions which include spilting a string with spaces (i.e. value.split(/[ -\/]/) )" do
      facet_url = @refine_project.link_to_facets({"company"=>'filter(forEach(forEach(value.split(/[ -\/]/),v,v.replace(/^[^\w\s]/,"")    ),v2,v2.replace(/[^\w\s]$/,"").toLowercase()),i,isNonBlank(i))'})
      assert_includes facet_url, "filter%28forEach%28forEach%28value.split%28%2F%5B%20-%5C%5C%2F%5D%2F%29%2Cv%2Cv.replace%28%2F%5E%5B%5E%5C%5Cw%5C%5Cs%5D%2F%2C%5C%22%5C%22%29%20%20%20%20%29%2Cv2%2Cv2.replace%28%2F%5B%5E%5C%5Cw%5C%5Cs%5D%24%2F%2C%5C%22%5C%22%29.toLowercase%28%29%29%2Ci%2CisNonBlank%28i%29%29%22%2C%22name%22%3A%22company%22%2C%22invert%22%3Afalse%7D%2C%22o%22%3A%7B%22sort%22%3A%22name%22%7D%7D%5D%7D"
    end

    it "creates working url for custom expressions which uses the equal operator '=='" do
      facet_url = @refine_project.link_to_facets({"transcript_company"=>'filter(forEach(cells.company.value.split(/[\p{Punct}[^\s\w]]/),company_part,or(with(value.replace(/[\p{Punct}[^\s\w]]/,"").phonetic(),left,with(phonetic(company_part),right,or(left==right,or(left.contains(right),right.contains(left))))),with(value.replace(/[\p{Punct}[^\s\w]]/,"").fingerprint(),left,with(fingerprint(company_part.replace(/[\p{Punct}[^\s\w]]/,"")),right,or(left==right,or(left.contains(right),right.contains(left))))))),v,v).uniques().length()>=1'})
      assert_includes facet_url, "filter%28forEach%28cells.company.value.split%28%2F%5B%5C%5Cp%7BPunct%7D%5B%5E%5C%5Cs%5C%5Cw%5D%5D%2F%29%2Ccompany_part%2Cor%28with%28value.replace%28%2F%5B%5C%5Cp%7BPunct%7D%5B%5E%5C%5Cs%5C%5Cw%5D%5D%2F%2C%5C%22%5C%22%29.phonetic%28%29%2Cleft%2Cwith%28phonetic%28company_part%29%2Cright%2Cor%28left%3D%3Dright%2Cor%28left.contains%28right%29%2Cright.contains%28left%29%29%29%29%29%2Cwith%28value.replace%28%2F%5B%5C%5Cp%7BPunct%7D%5B%5E%5C%5Cs%5C%5Cw%5D%5D%2F%2C%5C%22%5C%22%29.fingerprint%28%29%2Cleft%2Cwith%28fingerprint%28company_part.replace%28%2F%5B%5C%5Cp%7BPunct%7D%5B%5E%5C%5Cs%5C%5Cw%5D%5D%2F%2C%5C%22%5C%22%29%29%2Cright%2Cor%28left%3D%3Dright%2Cor%28left.contains%28right%29%2Cright.contains%28left%29%29%29%29%29%29%29%2Cv%2Cv%29.uniques%28%29.length%28%29%3E%3D1"
    end

    it "by generating urls based on a simple facet specification" do
      # urls need the terms facet structure in json, encoded, as the UI parameter
      raw_url = @refine_project.link_to_facets("Date")

      url = URI::parse(raw_url)

      assert !url.query.empty?

      params = Hash[url.query.split("&").map{|i| i.split("=")}]

      assert !params['ui'].nil?

      facet_spec = JSON::parse(URI::decode(params['ui']))
      assert_equal 1, facet_spec.fetch("facets").length

      assert_equal "Date", facet_spec.fetch("facets").first.fetch("c").fetch("columnName")
      assert_equal "Date", facet_spec.fetch("facets").first.fetch("c").fetch("name")
    end

    describe "depends on generating a ui query" do
      describe "valid facet query" do
        it "needs a control key ('c') for each facet" do
          structure = @refine_project.facet_parameters("Date")
          assert_includes structure.first.keys, "c"
        end

        it "each facet needs a columnName" do
          facet = @refine_project.facet_parameters("Date").first.fetch('c')
          assert_includes facet.keys, "columnName"
        end
        it "each facet needs an expression" do
          facet = @refine_project.facet_parameters("Date").first.fetch('c')
          assert_includes facet.keys, "expression"
        end
        it "each facet needs a name" do
          facet = @refine_project.facet_parameters("Date").first.fetch('c')
          assert_includes facet.keys, "name"
        end
      end

      it "creates text facets for each column name provided" do
        date_facet, company_facet = @refine_project.facet_parameters("Date","company")

        assert_equal "Date", date_facet.fetch("c").fetch("columnName")
        assert_equal "Date", date_facet.fetch("c").fetch("name")

        assert_equal "company", company_facet.fetch("c").fetch("columnName")
        assert_equal "company", company_facet.fetch("c").fetch("name")
      end

      describe "with custom expressions" do
        it "has a `value` expression by default" do
          date_facet, company_facet = @refine_project.facet_parameters("Date","company")

          assert_equal "value", date_facet.fetch("c").fetch("expression")
          assert_equal "value", company_facet.fetch("c").fetch("expression")
        end

        # our own expression
        it "sanitizes custom expressions by escaping backticks" do
          date_facet = @refine_project.link_to_facets("Date"=>'value. [\w\s] = ')
          assert_includes date_facet, "value.%20%5B%5C%5Cw%5C%5Cs%5D%20%3D%20"
        end

        it "can pass custom expressions through a hash" do
          date_facet, company_facet = @refine_project
            .facet_parameters({"Date" => "value.utcTime()"},{"Company"=>"value.titleCase()"})

          assert_equal "value.utcTime()", date_facet.fetch("c").fetch("expression")
          assert_equal "Date", date_facet.fetch("c").fetch("columnName")

          assert_equal "value.titleCase()", company_facet.fetch("c").fetch("expression")
          assert_equal "Company", company_facet.fetch("c").fetch("columnName")
        end
      end

      describe "with custom sorting" do
        # this adds an 'o' data structure for order

        it "sorts by `name` by default" do # ie existing test cases
          date_facet = @refine_project.facet_parameters("Date")
          assert_equal "name", date_facet.first.fetch("o").fetch("sort")
        end

        it "sorts by `count` when specified" do # need to choose a new signature / api
          date_facet =@refine_project.facet_parameters({"Date"=>["value.utcTime()", "sort_count"]})
          assert_equal "count", date_facet.first.fetch("o").fetch("sort")

        end
      end

      describe "inversion" do
        # find where to put these arguments in, probably 'c'
        it "default's to not inverted" do
          date_facet = @refine_project.facet_parameters("Date")
          assert_equal false, date_facet.first.fetch("c").fetch("invert")
        end
        it "can specify to invert" do
          date_facet = @refine_project.facet_parameters({"Date"=>["value.utcTime()", "invert"]})
          assert_equal true, date_facet.first.fetch("c").fetch("invert")
        end
      end
    end

    describe "compute_facets" do
      it "Request responds with error due to non existent column" do
        response = @refine_project.compute_facet({"transcript_fiscal_year"=> ["isNonBlank(value)"]})
        assert_equal("Error: No column named transcript_fiscal_year", response)
      end

      it "Request executes expression and sends response with the results" do
        response = @refine_project.compute_facet({"Column 1"=> ["isNonBlank(value)"]})
        assert_equal({true=>4}, response)
      end

      it "Request with faulty expression" do
        response = @refine_project.compute_facet({"Column 1"=> ["iBlank(value)"]})
        assert_equal("Error: Parsing error at offset 6: Unknown function or control named iBlank", response)
      end
    end

    it "generates a link to the server" do
      assert(URI::HTTP === URI::parse(@refine_project.link_to_facets("Date")))
    end

    # @refine_project.link_to_facets(...)
    # => http://foo.bar/project/adfasdfsdf
    # it "succeeds, with status 200 and a document" do
    #   assert(HTTPClient.get(@refine_project.link_to_facets("Date")).code == 200)
    # end
  end

  after do
    @refine_project.delete_project
  end

end
