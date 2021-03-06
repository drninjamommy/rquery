
flatten_with_sep <- function(list_of_lists, sep_list) {
  nl <- length(list_of_lists)
  if(nl<1) {
    return(list())
  }
  if(nl==1) {
    return(list_of_lists[[1]])
  }
  r <- vector(2*nl-1, mode = "list")
  r[seq_len(length(r))] <- sep_list
  r[2*seq_len(nl)-1] <- list_of_lists
  r <- unlist(r, recursive = FALSE)
  r
}


#' Count NULLs per row for given column set.
#'
#' Build a query that counts the number of nulls in each row.
#'
#' @param source incoming rel_op tree or data.frame.
#' @param cols character, columns to track
#' @param count character, column to write count in.
#' @return rel_op node or data.frame (depending on input).
#'
#' @seealso \code{\link{mark_null_cols}}, \code{\link{replace_null_cols}}
#'
#' @examples
#'
#'  my_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  winvector_temp_db_handle <- list(
#'    db = DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  )
#'  RSQLite::initExtension(winvector_temp_db_handle$db)
#'
#'  d <- dbi_copy_to(my_db, 'd',
#'                   data.frame(AUC = c(0.6, 0.5, NA),
#'                              R2 = c(1.0, 0.9, NA)))
#'  op_tree <- d %.>% count_null_cols(., c("AUC", "R2"), "nnull")
#'  cat(format(op_tree))
#'  sql <- to_sql(op_tree, my_db)
#'  cat(sql)
#'  DBI::dbGetQuery(my_db, sql)
#'
#'  # ad-hoc mode
#'  data.frame(AUC=c(1,NA,0.5), R2=c(NA,1,0)) %.>% op_tree
#'
#'  # cleanup
#'  rm(list = "winvector_temp_db_handle")
#'  DBI::dbDisconnect(my_db)
#'
#' @export
#'
count_null_cols <- function(source, cols, count) {
  nc <- length(cols)
  if(nc<1) {
    stop("rquery::count_null_cols need at least one column name")
  }
  bad_cols <- setdiff(cols, column_names(source))
  if(length(bad_cols)>0) {
    stop(paste("rquery::count_null_cols unknown columns:",
               paste(bad_cols, collapse = ", ")))
  }
  terms <- lapply(cols,
                  function(ci) {
                    list("( CASE WHEN (",
                         as.name(ci),
                         "IS NULL ) THEN 1 ELSE 0 END )")
                  })
  expr <- flatten_with_sep(terms, list("+"))
  nd <- sql_node(source, list(count = expr),
                 orig_columns = TRUE)
  nd$display_form <- paste0("count_null_cols(",
                            paste(cols, collapse = ", "),
                            ")")
  nd
}


#' Indicate NULLs per row for given column set.
#'
#' Build a query that creates NULL indicators for nulls in slected columns.
#'
#' @param source incoming rel_op tree or data.frame.
#' @param cols named character, values are columns to track, names are where to land indicators.
#' @return rel_op node or data.frame (depending on input).
#'
#' @seealso \code{\link{count_null_cols}}, \code{\link{replace_null_cols}}
#'
#' @examples
#'
#'  my_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  winvector_temp_db_handle <- list(
#'    db = DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  )
#'  RSQLite::initExtension(winvector_temp_db_handle$db)
#'
#'  d <- dbi_copy_to(my_db, 'd',
#'                   data.frame(AUC = c(0.6, 0.5, NA),
#'                              R2 = c(1.0, 0.9, NA)))
#'  op_tree <- d %.>% mark_null_cols(., qc(AUC_NULL, R2_NULL) :=
#'                                      qc(AUC, R2))
#'  cat(format(op_tree))
#'  sql <- to_sql(op_tree, my_db)
#'  cat(sql)
#'  DBI::dbGetQuery(my_db, sql)
#'
#'  # ad-hoc mode
#'  data.frame(AUC=c(1,NA,0.5), R2=c(NA,1,0)) %.>% op_tree
#'
#'  # cleanup
#'  rm(list = "winvector_temp_db_handle")
#'  DBI::dbDisconnect(my_db)
#'
#' @export
#'
mark_null_cols <- function(source, cols) {
  if(length(intersect(names(cols), as.character(cols)))>0) {
    stop("mark_null_cols: names can not intersect values")
  }
  nc <- length(cols)
  if(nc<1) {
    stop("rquery::mark_null_cols need at least one column name")
  }
  bad_cols <- setdiff(cols, column_names(source))
  if(length(bad_cols)>0) {
    stop(paste("rquery::mark_null_cols unknown columns:",
               paste(bad_cols, collapse = ", ")))
  }
  terms <- lapply(cols,
                  function(ci) {
                    list(as.name(ci),
                         "IS NULL")
                  })
  names(terms) <- names(cols)
  nd <- sql_node(source, terms,
           orig_columns = TRUE)
  nd$display_form <- paste0("mark_null_cols(",
                            wrapr::map_to_char(cols),
                            ")")
  nd
}

#' Replace or COALESCE out NULLs per row for given column set.
#'
#' Build a query that replaces NULL values in selected columns.
#'
#' @param source incoming rel_op tree or data.frame.
#' @param cols character, columns to replace NULLs in.
#' @param val relpacement value.
#' @return rel_op node or data.frame (depending on input).
#'
#' @seealso \code{\link{count_null_cols}}, \code{\link{mark_null_cols}}
#'
#' @examples
#'
#'  my_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  winvector_temp_db_handle <- list(
#'    db = DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'  )
#'  RSQLite::initExtension(winvector_temp_db_handle$db)
#'
#'  d <- dbi_copy_to(my_db, 'd',
#'                   data.frame(AUC = c(NA, 0.5, NA),
#'                              R2 = c(1.0, 0.9, NA),
#'                              cat = c("a", NA, "c"),
#'                              stringsAsFactors = FALSE))
#'
#'  # numeric example
#'  op_tree <- d %.>% replace_null_cols(., qc(AUC, R2),
#'                                         0.0)
#'  cat(format(op_tree))
#'  sql <- to_sql(op_tree, my_db)
#'  cat(sql)
#'  DBI::dbGetQuery(my_db, sql)
#'
#'  # ad-hoc mode
#'  data.frame(AUC=c(1,NA,0.5), R2=c(NA,1,0), cat= NA) %.>% op_tree
#'
#'  # string example
#'  op_tree <- d %.>% replace_null_cols(., "cat", "")
#'  cat(format(op_tree))
#'  sql <- to_sql(op_tree, my_db)
#'  cat(sql)
#'  DBI::dbGetQuery(my_db, sql)
#'
#'  # cleanup
#'  rm(list = "winvector_temp_db_handle")
#'  DBI::dbDisconnect(my_db)
#'
#' @export
#'
replace_null_cols <- function(source, cols, val) {
  nc <- length(cols)
  if(nc<1) {
    stop("rquery::replace_null_cols need at least one column name")
  }
  bad_cols <- setdiff(cols, column_names(source))
  if(length(bad_cols)>0) {
    stop(paste("rquery::replace_null_cols unknown columns:",
               paste(bad_cols, collapse = ", ")))
  }
  source_cols <- column_names(source)
  others <- as.list(setdiff(source_cols, as.character(cols)))
  names(others) <- others
  terms <- lapply(cols,
                  function(ci) {
                    list("CASE WHEN",
                         as.name(ci),
                         "IS NULL THEN",
                         list(val), # get quoting
                         "ELSE",
                         as.name(ci),
                         "END")
                  })
  names(terms) <- cols
  nd <- sql_node(source, c(terms, others),
           orig_columns = FALSE)
  valstr <- format(val)
  if(is.character(val)) {
    valstr <- paste0('"', val, '"')
  }
  nd$display_form <- paste0("replace_null_cols(",
                            paste(cols, collapse = ", "),
                            "; ",
                            valstr,
                            ")")
  nd
}

