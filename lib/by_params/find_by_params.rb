# -*- encoding : utf-8 -*-
#这个模块主要用于nongren manager的查询任务，可以被复用在产品，订单，用户的查询#
module ByParams::FindByParams

  class << self
    def included(base)
      base.module_eval do
        extend(ClassMethods)
      end
    end
  end

  module ClassMethods    
    def find_by_params params
      builder = ByParams::FindByParams::CriteriaBuilder.new(self.all(), params)
      yield(builder) if block_given?
      builder.do_condition.do_search.do_filter.do_sort.do_pagination
    end
  end
  
  class CriteriaBuilder

    def initialize criteria, params
      @criteria = criteria
      @params  = params
      @per_page = 20
    end

    def filter field_name, &block
      filters[field_name] = block
    end

    def condition &block
      conditions << block
    end

    def per_page per_page
      @per_page = per_page
    end

    def do_condition
      conditions.each do |block|
        @criteria = block.call(@criteria)
      end
      return self
    end

    def do_search
      searchs = JSON.parse(@params[:search] || "[]" )
      searchs.each{|search| @criteria = @criteria.where(search["property"] => search["value"])}
      return self
    end

    def do_filter      
      all_filters = JSON.parse(@params[:filter] || "[]")
      all_filters.each do |filter|
        field = filter["field"]
        block = filters[field]
        if (block)
          @criteria = block.call(@criteria, filter["value"])
        else
          filter_by_type filter
        end
      end      
      return self
    end

    def do_sort
      sort = @params[:sort] || "created_at"
      dir = @params[:dir] || "DESC"
      @criteria = @criteria.order_by([sort, dir])
      return  self
    end

    def do_pagination
      page = @params[:page] || 1
      per_page = @params[:limit] || @params[:per_page] || @per_page
      
      @criteria = @criteria.paginate(:page => page, :per_page =>per_page)
    end

    private

    def filters
      @filters = @filters || {}
      return @filters
    end

    def conditions
      @conditions = @conditions || []
      return @conditions
    end

    def filter_by_type filter
      case filter["type"]

      when "list"
        @criteria = @criteria.any_in(filter["field"] => filter["value"])

      when "string"
        search = filter["value"]
        @criteria = @criteria.where(filter["field"] => Regexp.new("#{search}", Regexp::IGNORECASE) )
      end
    end

  end
end
