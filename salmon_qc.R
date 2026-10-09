#!/usr/bin/env Rscript
# Summarize Salmon quantification logs into a QC table.
#
# Usage:
#   Rscript salmon_qc.R LOG_OR_DIR [LOG_OR_DIR ...] [-o qc.csv] [--min-rate 70] [--plot qc.png]
#
# Directories are searched recursively for files named *quant*.log.
# Can also be used interactively: source("salmon_qc.R"); qc <- salmon_qc("salmon_output/")

parse_log <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[grepl(":", lines)]
  keys <- tolower(trimws(sub(":.*$", "", lines)))
  values <- trimws(sub("^[^:]*:", "", lines))
  fields <- setNames(as.list(values), keys)
  get <- function(key) if (is.null(fields[[key]])) NA_character_ else fields[[key]]

  frag <- regmatches(get("fragment length mean (sd)"),
                     regexec("([0-9.]+)\\s*\\(([0-9.]+)\\)", get("fragment length mean (sd)")))[[1]]

  data.frame(
    sample              = sample_name(path),
    library_type        = get("library type"),
    observed_fragments  = suppressWarnings(as.numeric(gsub(",", "", get("observed fragments")))),
    mapped_fragments    = suppressWarnings(as.numeric(gsub(",", "", get("mapped fragments")))),
    mapping_rate        = suppressWarnings(as.numeric(sub("%", "", get("mapping rate")))),
    equivalence_classes = suppressWarnings(as.numeric(get("number of equivalence classes"))),
    frag_len_mean       = if (length(frag) == 3) as.numeric(frag[2]) else NA_real_,
    frag_len_sd         = if (length(frag) == 3) as.numeric(frag[3]) else NA_real_,
    runtime_min         = runtime_minutes(get("start"), get("end")),
    stringsAsFactors    = FALSE
  )
}

# Use the parent directory name (Salmon's usual per-sample output dir), else the file name.
sample_name <- function(path) {
  parent <- basename(dirname(path))
  if (parent %in% c("logs", "aux_info")) parent <- basename(dirname(dirname(path)))
  if (parent %in% c("", ".")) parent <- tools::file_path_sans_ext(basename(path))
  parent
}

runtime_minutes <- function(start, end) {
  fmt <- "%a %b %d %H:%M:%S %Y"
  t0 <- as.POSIXct(start, format = fmt, tz = "UTC")
  t1 <- as.POSIXct(end, format = fmt, tz = "UTC")
  if (is.na(t0) || is.na(t1)) return(NA_real_)
  round(as.numeric(difftime(t1, t0, units = "mins")), 1)
}

find_logs <- function(inputs) {
  unlist(lapply(inputs, function(p) {
    if (dir.exists(p)) {
      sort(list.files(p, pattern = "quant.*\\.log$", recursive = TRUE, full.names = TRUE))
    } else if (file.exists(p)) {
      p
    } else {
      warning(p, " not found, skipping", call. = FALSE)
      character(0)
    }
  }))
}

salmon_qc <- function(inputs, min_rate = 70) {
  logs <- find_logs(inputs)
  if (length(logs) == 0) stop("no Salmon logs found")
  qc <- do.call(rbind, lapply(logs, parse_log))
  qc$status <- ifelse(is.na(qc$mapping_rate), "UNKNOWN",
                      ifelse(qc$mapping_rate < min_rate, "LOW", "OK"))
  qc
}

plot_qc <- function(qc, file, min_rate = 70) {
  png(file, width = 900, height = 500)
  op <- par(mar = c(8, 5, 3, 1))
  cols <- ifelse(qc$status == "OK", "#4C9F70", "#D1495B")
  bp <- barplot(qc$mapping_rate, names.arg = qc$sample, las = 2, col = cols,
                ylim = c(0, 100), ylab = "Mapping rate (%)", main = "Salmon mapping rate")
  abline(h = min_rate, lty = 2)
  text(bp, qc$mapping_rate, sprintf("%.1f", qc$mapping_rate), pos = 3, cex = 0.8)
  par(op)
  dev.off()
}

main <- function(args) {
  output <- NULL; plot_file <- NULL; min_rate <- 70; inputs <- character(0)
  i <- 1
  while (i <= length(args)) {
    a <- args[i]
    if (a %in% c("-o", "--output")) { output <- args[i + 1]; i <- i + 1 }
    else if (a == "--min-rate") { min_rate <- as.numeric(args[i + 1]); i <- i + 1 }
    else if (a == "--plot") { plot_file <- args[i + 1]; i <- i + 1 }
    else if (a %in% c("-h", "--help")) {
      cat("Usage: Rscript salmon_qc.R LOG_OR_DIR [...] [-o qc.csv] [--min-rate 70] [--plot qc.png]\n")
      quit(status = 0)
    }
    else inputs <- c(inputs, a)
    i <- i + 1
  }
  if (length(inputs) == 0) stop("give at least one Salmon log file or directory")

  qc <- salmon_qc(inputs, min_rate)
  if (is.null(output)) write.csv(qc, stdout(), row.names = FALSE)
  else write.csv(qc, output, row.names = FALSE)
  if (!is.null(plot_file)) plot_qc(qc, plot_file, min_rate)

  flagged <- qc$sample[qc$status != "OK"]
  message(nrow(qc), " sample(s) checked, ", length(flagged), " flagged",
          if (length(flagged)) paste0(": ", paste(flagged, collapse = ", ")) else "")
}

if (!interactive() && sys.nframe() == 0) main(commandArgs(trailingOnly = TRUE))
