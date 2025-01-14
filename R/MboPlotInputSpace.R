#' @title MboPlotInputSpace
#'
#' @include MboPlot-helpers-general.R
#'
#' @import checkmate
#' @import mlrMBO
#' @import ParamHelpers
#' @import dplyr
#' @import BBmisc
#'
#' @importFrom R6 R6Class
#' @importFrom reshape2 melt
#' @importFrom magrittr %T>%
#' @importFrom tidyr gather
#' @importFrom dplyr select_if
#' @importFrom scales number_format
#' @importFrom ggpubr ggarrange
#'
#' @description
#' This class generates plots for the visualization of the input space given
#' prior and posterior distributions of the evaluated parameters in the mbo run.
#'
#' @export
MboPlotInputSpace = R6Class(
  "MboPlotInputSpace",
  inherit = MboPlot,
  public = list(
    #' @description
    #' Creates a new instance of this [R6][R6::R6Class] class.
    #'
    #' @param opt_state ([OptState]).
    initialize = function(opt_state) {
      param_set = makeParamSet(makeLogicalParam("include_init_design_sampling_distribution"))
      param_vals = list(include_init_design_sampling_distribution = TRUE) # default value, else set with function `set_param_vals()`
      super$initialize(opt_state, param_set, param_vals)
    },
    #' @description
    #' Plots prior distributions of mbo run specified in the set of parameters.
    #'
    #' @param include_init_design_sampling_distribution (\code{logical(1) | TRUE})\cr
    #' Specifies if bar chart over sampled prior should also be included in plot.
    #' @param search_space_components (\code{list()})\cr
    #' Specifies the search space components which should be plotted.
    #'
    #' @return ([ggplot]).
    plot = function(include_init_design_sampling_distribution = self$param_vals$include_init_design_sampling_distribution, search_space_components = getParamIds(self$opt_state$opt.path$par.set)[1:2]) {
      df_x = getOptPathX(self$opt_state$opt.path)
      df_x_comp =  df_x[, which(colnames(df_x) %in% search_space_components), drop = FALSE]
      length_num = sum(sapply(df_x_comp, is.numeric))
      length_disc = sum(sapply(df_x_comp, is.factor))

      n = 1000L # set for the sampling, i.e. if smoother sampling required set n to a larger number.
      # get all numeric parameters from the evaluated search space, i.e. from the opt.path
      df_wide_post_num = df_x_comp %>%
        select_if(is.numeric)
      # cbind with label for plot.
      df_wide_post_num = cbind(type = "entire optimization run", df_wide_post_num)
      # same for discrete search space components
      df_wide_post_disc = df_x_comp %>%
        select_if(is.factor)
      df_wide_post_disc = cbind(type = "entire optimization run", df_wide_post_disc)
      # generate radnom design according to specified parameters, consider possible transformations, i.e. trafo = TRUE
      df_wide_prior_num = generateRandomDesign(n, self$opt_state$opt.path$par.set, trafo = TRUE) %>%
        select_if(is.numeric) %>%
        select(matches(search_space_components))
      # cbind with label for plot.
      df_wide_prior_num = cbind(type = "init design sampling distribution", df_wide_prior_num)
      df_wide_prior_disc = generateRandomDesign(n, self$opt_state$opt.path$par.set,  trafo = TRUE) %>%
        select_if(is.factor) %>%
        select(matches(search_space_components))

      df_wide_prior_disc = cbind(type = "init design sampling distribution", df_wide_prior_disc)
      # convert to long format for plotting.
      df_long_num = rbind(wideToLong(df_wide_post_num), wideToLong(df_wide_prior_num))
      df_long_disc = rbind(wideToLong(df_wide_post_disc), wideToLong(df_wide_prior_disc))
      # extract column numbers of df's, to see if we need to create a facet for both, numeric and discrete search space components.
      ncols_df = c(ncol(df_wide_post_num), ncol(df_wide_post_disc))
      # initialize both gg objects with NULL. Needed if one category is empty, e.g. no discrete search space components
      gg_num = NULL
      gg_disc = NULL
      # only plot if numeric parameters present in the search space
      if (ncols_df[1] > 1) {
        gg_num = ggplot(filter(df_long_num, type == "entire optimization run"), aes(x = Value, fill = type))
        gg_num = gg_num + geom_bar(aes(y = ..prop.., group = 1), alpha = .4)
        if (include_init_design_sampling_distribution) {
          gg_num = gg_num + geom_bar(data = filter(df_long_num, type == "init design sampling distribution"),
                                     mapping = aes(x = Value, y = ..prop.., group = 1, fill = type),
                                     alpha = .4)
        }
        gg_num = gg_num + scale_x_binned(n.breaks = 20, labels = scales::number_format(accuracy = .1))
        gg_num = gg_num + facet_wrap(Param ~ ., scales = "free")
        gg_num = gg_num + ggtitle("MBO search space: evaluated numeric parameters")
        gg_num = gg_num + xlab("Param value")
        gg_num = gg_num + theme(plot.title = element_text(hjust = 0.5),
                                axis.text.x = element_text(angle = 45, hjust = 1))
      }
      # only plot if discrete parameters present in the search space
      if (ncols_df[2] > 1) {
        gg_disc = ggplot(filter(df_long_disc, type == "entire optimization run"), aes(x = Value))
        gg_disc = gg_disc + geom_bar(aes(y = ..prop.., group = 2, fill = type), alpha = .4)
        if (include_init_design_sampling_distribution) {
        gg_disc = gg_disc + geom_bar(data = filter(df_long_disc, type == "init design sampling distribution"),
                                     mapping = aes(y = ..prop.., group = 1, fill = type),
                                     alpha = .4)
        }
        gg_disc = gg_disc + facet_wrap(Param ~ ., scales = "free")
        gg_disc = gg_disc + ggtitle("MBO search space: evaluated discrete parameters")
        gg_disc = gg_disc + xlab("Param value")
        gg_disc = gg_disc + theme(plot.title = element_text(hjust = 0.5))
      }
      # some specifications for partitioning the plot area (split between space required for numeric search space components
      # facet of plots and discret search space components facet of plots).
      if (ncols_df[2] <= 1) {
        gg = gg_num
      } else {
        if (ncols_df[1] <= 1) {
          gg = gg_disc
        } else {
      gg = ggarrange(gg_num, gg_disc, nrow = ifelse(length_disc >0, 2, 1),
                    heights = ifelse(c(length_disc >0,length_disc >0) , c(round(log(length_num/length_disc)+0.51), 1)))
      }}
      return(gg)
    }
  )
)

