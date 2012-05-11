# -*- encoding : utf-8 -*-
require 'spec_helper'


describe ByParams::FindByParams do

  before :each do
    @criteria = mock("Criteria")
    @params = {}
    @builder = ByParams::FindByParams::CriteriaBuilder.new(@criteria, @params)
  end

  context "find_by_params" do

    before :each do
      class TestClass < ActiveResource::Base
        include ByParams::FindByParams
        def self.all
          return "A criteria"
        end
      end

      ByParams::FindByParams::CriteriaBuilder.should_receive(:new).with("A criteria", @params).and_return(@builder)
      @builder.should_receive(:do_condition).once.ordered.and_return(@builder)
      @builder.should_receive(:do_search).once.ordered.and_return(@builder)
      @builder.should_receive(:do_filter).once.ordered.and_return(@builder)
      @builder.should_receive(:do_sort).once.ordered.and_return(@builder)
      @builder.should_receive(:do_pagination).once.ordered.and_return(@builder)
    end

    it %{应该顺序地执行"条件", "搜索", "过滤", "排序", "分页"操作} do      
      TestClass.find_by_params(@params)
    end

    it "应该可以定制builder" do
      TestClass.find_by_params(@params) do |builder|
        builder.should == @builder
      end
    end
  end

  context "条件" do
    after :each do
      @builder.do_condition
    end

    it "当有单个定制条件时，应该应用单个定制的条件" do
      @builder.condition do |criteria|
        criteria.where(:state => "somestate")
      end

      @criteria.should_receive(:where).with(:state => "somestate")
    end

    it "当有多个定制条件时，应该应用多个定制的条件" do
      @builder.condition do |criteria|
        criteria.where(:state => "somestate")
      end
      
      @builder.condition do |criteria|
        criteria.where(:onsale => false)
      end

      second_criteria = mock("Second Criteria")
      @criteria.should_receive(:where).with(:state => "somestate").and_return second_criteria
      second_criteria.should_receive(:where).with(:onsale => false)
    end
  end

   context "搜索" do
    after :each do
      @builder.do_search
    end

    it "当params中没有搜索信息时，不应该执行搜索" do
      @criteria.should_not_receive(:where)
    end

    it "当params中有:search参数时，应该可以搜素单个条件" do
      @params[:search]=[{:property =>"id", :value=>"someid"}].to_json
      @criteria.should_receive(:where).with("id" => "someid")
    end

    it "当params中有:search参数时，应该可以搜素所有条件" do
      @params[:search]=[{:property =>"id", :value=>"someid"},{:property => "name", :value=>"somename"}].to_json

      second_criteria = mock("Second Criteria")

      @criteria.should_receive(:where).with("id" => "someid").and_return(second_criteria)
      second_criteria.should_receive(:where).with("name" => "somename")
    end
  end

  context "过滤" do
    after :each do
      @builder.do_filter
    end

    it "当params中没有:filter参数时，不应该执行过滤" do
      @criteria.should_not_receive(:where)
      @criteria.should_not_receive(:any_in)
      @criteria.should_not_receive(:also_in)
      @criteria.should_not_receive(:and)
      @criteria.should_not_receive(:or)
    end

    it "当params中有:filter参数且过滤信息类型为list时，应该用Criteria#any_in来应用所有的过滤内容" do
      @params[:filter]=[{:type=>"list", :field=>"name", :value=>["a","b","c"]}].to_json
      @criteria.should_receive(:any_in).with("name" => ["a","b","c"])
    end

    it "当params中有:filter参数且过滤信息类型为string时，应该用过滤内容的Regex来过滤记录" do
      @params[:filter]=[{:type=>"string", :field=>"name", :value=>"al"}].to_json
      @criteria.should_receive(:where).with("name" => /al/i)
    end

    it "可以根据字段定制过滤逻辑" do
      @builder.filter "name" do |criteria, value|
        value.should == ["a","b"]
        criteria.should == @criteria
        criteria.any_of(["name" => "a"],["name" => "b"])
      end

      @params[:filter]=[{:type=>"list", :field=>"name", :value=>["a","b"]}].to_json
      @criteria.should_receive(:any_of).with(["name" => "a"],["name" => "b"])
    end
  end
  
  context "排序" do
    after :each do
      @builder.do_sort
    end
    
    it "当params中没有排序信息时，应该按默认的created_at降序排序" do
      @criteria.should_receive(:order_by).with(["created_at", "DESC"])
    end

    it "当params中有:sort参数时，应该按params[:sort]指定的字段排序" do
      @params[:sort] = "name"
      @criteria.should_receive(:order_by).with(["name", "DESC"])
    end
    
    it "当params中有[:dir]时，应该按params[:dir]指定的顺序排序" do
      @params[:sort] = "name"
      @params[:dir] = "ASC"
      @criteria.should_receive(:order_by).with(["name", "ASC"])
    end
    
  end

  context "分页" do
    after :each do
      @builder.do_pagination
    end

    it "当params中没有分页信息时，应该默认从第一页开始每页20条记录分页" do
      @criteria.should_receive(:paginate).with(:page => 1, :per_page=>20)
    end

    it "当params中有:page参数时, 应该返回params[:limit]指定的页" do
      @params[:page] = 2
      @criteria.should_receive(:paginate).with(:page => 2, :per_page=>20)
    end

    it "当params中有:limit参数时, 应该在每页中返回params[:limit]指定的记录数" do
      @params[:limit] = 100
      @criteria.should_receive(:paginate).with(:page => 1, :per_page=>100)
    end

    it "可以修改默认的每页记录长度" do
      @builder.per_page 10
      @criteria.should_receive(:paginate).with(:page => 1, :per_page=>10)
    end
  end
  
end
