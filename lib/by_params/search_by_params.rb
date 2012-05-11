#这个模块主要用于扩展Model的查询功能
module ByParams
  
  module SearchByParams

    class << self
      def included(base)
        base.module_eval do
          extend(ClassMethods)
        end
      end
    end

    module ClassMethods    
      def search_by params=nil     
        self.search do    
          search_builder = SearchBuilder.new(params||{}, self)          
          
          yield(search_builder) if block_given?
          search_builder.process_filters
          search_builder.do_filter
          search_builder.do_fulltext
          search_builder.do_sort
          search_builder.do_pagination          
          search_builder.do_facet          
        end
      end
    end
  
    #FIXME:: rename SearchBuilder to SearchConfig
    class SearchBuilder
      attr_accessor :per_page
      
      def initialize params, dsl
        @params  = params
        @dsl = dsl
        @customised_filters={}
        @facets =[]
        @filters = []
        @dependent_facets={}
      end 
      
      def facet_for filter, dep_filter=nil, &block 
        if (dep_filter)
          @dependent_facets[filter]=dep_filter
        else
          @facets << filter
        end
      end
      
      def for_filter name, value, &block
        filter = @customised_filters[name] || []
        filter << [value, block]
        @customised_filters[name] = filter
      end
      
      #TODO:: spec on the default filters
      def with name, value
        @filters << {:name=>name, :value=>value}
      end
      
      def process_filters
        filters = search_params :filters
        return unless filters
        
        filter_names = filters.collect{|filter| filter[:name].to_sym}
        
        @params[:search][:filters] = filters.select do |filter|
          name = filter[:name].to_sym
          if (@dependent_facets.values.include? name)
            filter_names.include?(@dependent_facets.index(name))
          else
            true
          end
        end
      end
      
      def do_fulltext
        t = search_params(:q)
        @dsl.fulltext(t) if t
      end
      
      def do_filter
        filters = @filters + (search_params(:filters) || [])
        return if filters.empty?       
        
        filters.each do |filter|
          name = filter[:name].to_sym
          value = filter[:value]
          
          if (@customised_filters.include? name)
            filter = @customised_filters[name].select{|item| item[0] == value}.first
            @dsl.instance_eval(&filter[1]) if filter
          else
            case filter[:op] || "eq"
            when "or" , "eq"
              @dsl.with(name, value)
            when "and"            
              value.each{|v| @dsl.with name, v} if (value.respond_to? :each)
            end
          end
          
        end
        
      end
      
      def do_sort
        sort = @params[:sort] || :created_at
        dir = @params[:dir] || :desc
        @dsl.order_by(sort.to_sym, dir.to_s.downcase.to_sym)
      end

      def do_pagination
        page = @params[:page] || 1
        count = @params[:limit] || @params[:per_page] || per_page || 10
        @dsl.paginate :page=>page.to_i, :per_page=>count.to_i
      end
      
      def do_facet
        all_procs = all_facet_procs
        filters = search_params(:filters) || {}
        
        filter_names = filters.collect{|filter| filter[:name].to_sym}        
        applied_procs = @facets.select{|name| !filter_names.include? name}.collect{|name| all_procs[name]} +  
          @dependent_facets.select{|name, dep| filter_names.include?(name) && !filter_names.include?(dep)}.collect{|item| all_procs[item[1]]}        
        
        applied_procs.each{|proc| @dsl.instance_eval(&proc) if proc}
      end
    
      private
      
      def all_facet_procs
        all={}
        @customised_filters.each{|name, filter|  all[name] = create_query_facet(name, filter)}
        (@facets + @dependent_facets.values).each{|name| all[name] = Proc.new{facet name} unless all[name]}
        return all
      end
      
      def create_query_facet name, filter
        return Proc.new do
          facet name do 
            filter.each {|item| row(item[0],&item[1])}    
          end
        end
      end
      
      def search_params key
        search_params = @params[:search]
        return nil unless search_params
        
        return search_params[key]
      end
      
      
    end
  end
end