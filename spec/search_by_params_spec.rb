# -*- encoding : utf-8 -*-
require 'spec_helper'

describe ByParams::SearchByParams do
  
  before :each do
    class TestClass
      include ByParams::SearchByParams
      def self.search &block        
        dsl.instance_eval(&block)      
      end
      
      class << self
        attr_accessor :dsl
      end      
    end

    TestClass.dsl =  mock("sunspot dsl", :fulltext=>"", :with=>"", :order_by=>"", :paginate=>"", :facet=>"")
  end  
    
    
  describe "全文搜索" do
    it "应该可以搜索params中的search文本" do
      TestClass.dsl.should_receive(:fulltext).with("a place")      
      TestClass.search_by(:search=>{:q => "a place"})     
    end   
  end
  
    
  describe "过滤" do
  
    context "当params filter的value是单一值时" do
      it "应该可以过滤字段中有这个value的文档" do
        TestClass.dsl.should_receive(:with).with(:city, "上海")
        TestClass.search_by(:search=>{:filters=>[{:name=>"city", :value=>"上海", :op=>"eq"}]})
      end        
    end
      
    context "当params filter的value是一组值时" do
      it "可以过滤字段中有这个value的文档(OR操作)" do
        TestClass.dsl.should_receive(:with).with(:city, ["上海","北京"])
        TestClass.search_by(:search=>{:filters=>[{:name=>"city", :value=>["上海","北京"], :op=>"or"}]})
      end
        
      it "可以过滤字段中包含所有value的文档(AND操作)" do
        TestClass.dsl.should_receive(:with).with(:venue_tag, "婚庆").once
        TestClass.dsl.should_receive(:with).with(:venue_tag, "饭店").once
        TestClass.search_by(:search=>{:filters =>[{:name=>"venue_tag", :value=>["婚庆","饭店"], :op=>"and"}]})
      end
    end
    
    context "定制化的属性" do
      it "可以query定制的属性" do
        TestClass.dsl.should_receive(:with).with(:open_year, 1990..2000).once        
        TestClass.search_by(:search=>{:filters =>[{:name =>"decade", :value=>"90年代", :op=>"eq"}]}) do |builder|
          builder.for_filter(:decade, "90年代"){with :open_year, 1990..2000}  
          builder.for_filter(:decade, "2000-2009"){with :open_year, 2000..2009}
        end        
      end
      
    end
    
    context "从属的过滤器" do
      
      it "如果有过滤器且仅包含从属于某个facet的field，不应该过滤这个field" do
        TestClass.dsl.should_not_receive(:facet).with(:area)
        TestClass.dsl.should_receive(:facet).with(:city)
        TestClass.dsl.should_not_receive(:with).with(:area, "徐汇区")
      
        parmas = {:search=>{:filters=>[{:name=>"area", :value=>"徐汇区",:op=>"eq"}]}}
        
        TestClass.search_by(parmas) do |builder|
          builder.facet_for(:city)
          builder.facet_for(:city, :area)
        end
        
        parmas[:search][:filters].count.should == 0
      end      
    end
  end
    
    
  describe "排序" do
    it "可以按sort的字段，dir的顺序排序" do
      TestClass.dsl.should_receive(:order_by).with(:year, :asc)
      TestClass.search_by(:sort =>"year", :dir=>"ASC")
    end
  end
    
  describe "分页" do
    it "可以按页数和每页需要的文档分页" do
      TestClass.dsl.should_receive(:paginate).with(:page=>1, :per_page=>10)
      TestClass.search_by(:page =>"1", :limit=>"10")
    end
    
    it "可以定制每页的结果数量" do
      TestClass.dsl.should_receive(:paginate).with(:page=>1, :per_page=>20)
      TestClass.search_by(:page =>"1") do |search_builder|
        search_builder.per_page = 20
      end
    end
  end
  
  describe "Facet" do        
    
    it "可以为被定制化的属性生成facet" do     
      TestClass.dsl.should_receive(:facet).with(:decade).and_yield() do |context|
        context.should_receive(:row).with("90年代")
        context.should_receive(:row).with("2000-2009")
      end
      
      TestClass.search_by do |builder|
        builder.for_filter(:decade, "90年代"){with :open_year, 1990..2000}  
        builder.for_filter(:decade, "2000-2009"){with :open_year, 2000..2009}        
        builder.facet_for(:decade)
      end
    end
    
    context "没有过滤器时" do
      it "应该构建所有第一层的facet" do      
        TestClass.dsl.should_receive(:facet).with(:city).once
        TestClass.dsl.should_not_receive(:facet).with(:area)
        
        TestClass.search_by do |builder|
          builder.facet_for(:city)
          builder.facet_for(:city, :area)
        end
      end
    end
    
    context "有过滤器时" do
      it "不应该为已被过滤的field构建facet" do      
        TestClass.dsl.should_not_receive(:facet).with(:city)
        TestClass.search_by(:search=>{:filters=>[{:name=>"city",:value=>"上海"}]}) do |builder|
          builder.facet_for(:city)
        end
      end
      
      it "应该为从属于已被过滤的field构建facet" do
        TestClass.dsl.should_receive(:facet).with(:area).once
        TestClass.dsl.should_not_receive(:facet).with(:city)

        TestClass.search_by(:search=>{:filters=>[{:name=>"city",:value=>"上海"}]}) do |builder|
          builder.facet_for(:city)
          builder.facet_for(:city, :area)
        end
      end
      
      it "如果一个field和从属于这个field的field都被过滤了，不应该构建facets" do
        TestClass.dsl.should_not_receive(:facet).with(:area)
        TestClass.dsl.should_not_receive(:facet).with(:city)

        TestClass.search_by(:search=>{:filters=>[{:name=>"city",:value=>"上海"},{:name=>"area", :value=>"徐汇区"}]}) do |builder|
          builder.facet_for(:city)
          builder.facet_for(:city, :area)
        end
      end
    
    end
   
    
  end
  
  
end